defmodule Mix.Tasks.Phx.Install.Core do
  @moduledoc """
  Installs the core Phoenix application structure.

  This task sets up:
  - OTP Application module with supervision tree
  - Config files (config.exs, dev.exs, test.exs, prod.exs, runtime.exs)
  - Formatter configuration
  - Test helper

  ## Usage

      mix phx.install.core

  This task is typically called by `mix phx.install` rather than directly.
  """
  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :phoenix,
      example: "mix phx.install.core",
      adds_deps: [{:phoenix, "~> 1.7"}],
      schema: [
        signing_salt: :string,
        secret_key_base_dev: :string,
        secret_key_base_test: :string
      ]
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    app_name = Igniter.Project.Application.app_name(igniter)
    app_module = Igniter.Project.Module.module_name_prefix(igniter)
    web_module = Igniter.Libs.Phoenix.web_module(igniter)
    endpoint_module = Module.concat(web_module, Endpoint)

    opts = igniter.args.options

    secrets = %{
      signing_salt: opts[:signing_salt] || PhxInstall.random_string(8),
      secret_key_base_dev: opts[:secret_key_base_dev] || PhxInstall.random_string(64),
      secret_key_base_test: opts[:secret_key_base_test] || PhxInstall.random_string(64)
    }

    application_module = Module.concat(app_module, Application)

    igniter
    |> add_phoenix_extension()
    |> create_application_module(app_name, app_module, web_module, endpoint_module)
    |> set_application_mod(application_module)
    |> set_project_listeners()
    |> configure_base_config(app_name, app_module, web_module, endpoint_module, secrets)
    |> configure_dev(app_name, endpoint_module, secrets)
    |> configure_test(app_name, endpoint_module, secrets)
    |> configure_prod(app_name, endpoint_module)
    |> configure_runtime(app_name, endpoint_module)
    |> configure_formatter()
    |> create_test_helper()
  end

  defp set_application_mod(igniter, application_module) do
    Igniter.update_elixir_file(igniter, "mix.exs", fn zipper ->
      with {:ok, zipper} <- Igniter.Code.Module.move_to_module_using(zipper, Mix.Project),
           {:ok, zipper} <- Igniter.Code.Function.move_to_def(zipper, :application, 0) do
        zipper
        |> Igniter.Code.Common.rightmost()
        |> Igniter.Code.Keyword.set_keyword_key(
          :mod,
          {application_module, []},
          &replace_application_mod(&1, application_module)
        )
      end
    end)
  end

  defp replace_application_mod(zipper, application_module) do
    code =
      {application_module, []}
      |> Sourceror.to_string()
      |> Sourceror.parse_string!()

    {:ok, Igniter.Code.Common.replace_code(zipper, code)}
  end

  defp set_project_listeners(igniter) do
    Igniter.Project.MixProject.update(igniter, :project, [:listeners], fn
      nil -> {:ok, {:code, Sourceror.parse_string!("[Phoenix.CodeReloader]")}}
      zipper -> {:ok, zipper}
    end)
  end

  defp add_phoenix_extension(igniter) do
    Igniter.Project.IgniterConfig.add_extension(igniter, Igniter.Extensions.Phoenix)
  end

  defp create_application_module(igniter, app_name, app_module, web_module, endpoint_module) do
    application_module = Module.concat(app_module, Application)

    Igniter.Project.Module.find_and_update_or_create_module(
      igniter,
      application_module,
      """
      @moduledoc false

      use Application

      @impl true
      def start(_type, _args) do
        children = [
          #{inspect(Module.concat(web_module, :Telemetry))},
          {DNSCluster, query: Application.get_env(#{inspect(app_name)}, :dns_cluster_query) || :ignore},
          {Phoenix.PubSub, name: #{inspect(Module.concat(app_module, :PubSub))}},
          #{inspect(endpoint_module)}
        ]

        opts = [strategy: :one_for_one, name: #{inspect(Module.concat(app_module, :Supervisor))}]
        Supervisor.start_link(children, opts)
      end

      @impl true
      def config_change(changed, _new, removed) do
        #{inspect(endpoint_module)}.config_change(changed, removed)
        :ok
      end
      """,
      fn zipper -> {:ok, zipper} end
    )
  end

  defp configure_base_config(igniter, app_name, app_module, web_module, endpoint_module, secrets) do
    igniter
    |> Igniter.Project.Config.configure(
      "config.exs",
      app_name,
      [endpoint_module],
      {:code,
       Sourceror.parse_string!("""
       [
         url: [host: "localhost"],
         adapter: Bandit.PhoenixAdapter,
         render_errors: [
           formats: [json: #{inspect(Module.concat(web_module, :ErrorJSON))}],
           layout: false
         ],
         pubsub_server: #{inspect(Module.concat(app_module, :PubSub))},
         live_view: [signing_salt: #{inspect(secrets.signing_salt)}]
       ]
       """)}
    )
    |> Igniter.Project.Config.configure(
      "config.exs",
      :logger,
      [:default_formatter],
      {:code,
       Sourceror.parse_string!("""
       [format: "$time $metadata[$level] $message\\n", metadata: [:request_id]]
       """)}
    )
    |> Igniter.Project.Config.configure(
      "config.exs",
      :phoenix,
      [:json_library],
      Jason
    )
  end

  defp configure_dev(igniter, app_name, endpoint_module, secrets) do
    igniter
    |> Igniter.Project.Config.configure(
      "dev.exs",
      app_name,
      [endpoint_module],
      {:code,
       Sourceror.parse_string!("""
       [
         http: [ip: {127, 0, 0, 1}, port: 4000],
         check_origin: false,
         code_reloader: true,
         debug_errors: true,
         secret_key_base: #{inspect(secrets.secret_key_base_dev)}
       ]
       """)}
    )
    |> Igniter.Project.Config.configure("dev.exs", app_name, [:dev_routes], true)
    |> Igniter.Project.Config.configure(
      "dev.exs",
      :logger,
      [:default_formatter, :format],
      "[$level] $message\n"
    )
    |> Igniter.Project.Config.configure("dev.exs", :phoenix, [:stacktrace_depth], 20)
    |> Igniter.Project.Config.configure("dev.exs", :phoenix, [:plug_init_mode], :runtime)
  end

  defp configure_test(igniter, app_name, endpoint_module, secrets) do
    igniter
    |> Igniter.Project.Config.configure(
      "test.exs",
      app_name,
      [endpoint_module],
      {:code,
       Sourceror.parse_string!("""
       [
         http: [ip: {127, 0, 0, 1}, port: 4002],
         secret_key_base: #{inspect(secrets.secret_key_base_test)},
         server: false
       ]
       """)}
    )
    |> Igniter.Project.Config.configure("test.exs", :logger, [:level], :warning)
    |> Igniter.Project.Config.configure("test.exs", :phoenix, [:plug_init_mode], :runtime)
  end

  defp configure_prod(igniter, app_name, endpoint_module) do
    igniter
    |> Igniter.Project.Config.configure(
      "prod.exs",
      app_name,
      [endpoint_module],
      {:code,
       Sourceror.parse_string!("""
       [
         force_ssl: [rewrite_on: [:x_forwarded_proto]],
         exclude: [hosts: ["localhost", "127.0.0.1"]]
       ]
       """)}
    )
    |> Igniter.Project.Config.configure("prod.exs", :logger, [:level], :info)
  end

  defp configure_runtime(igniter, app_name, endpoint_module) do
    runtime_content = """
    import Config

    if System.get_env("PHX_SERVER") do
      config #{inspect(app_name)}, #{inspect(endpoint_module)}, server: true
    end

    config #{inspect(app_name)}, #{inspect(endpoint_module)},
      http: [port: String.to_integer(System.get_env("PORT", "4000"))]

    if config_env() == :prod do
      secret_key_base =
        System.get_env("SECRET_KEY_BASE") ||
          raise \"\"\"
          environment variable SECRET_KEY_BASE is missing.
          You can generate one by calling: mix phx.gen.secret
          \"\"\"

      host = System.get_env("PHX_HOST") || "example.com"

      config #{inspect(app_name)}, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

      config #{inspect(app_name)}, #{inspect(endpoint_module)},
        url: [host: host, port: 443, scheme: "https"],
        http: [ip: {0, 0, 0, 0, 0, 0, 0, 0}],
        secret_key_base: secret_key_base
    end
    """

    Igniter.create_or_update_elixir_file(
      igniter,
      "config/runtime.exs",
      runtime_content,
      fn zipper -> {:ok, zipper} end
    )
  end

  defp configure_formatter(igniter) do
    Igniter.Project.Formatter.import_dep(igniter, :phoenix)
  end

  defp create_test_helper(igniter) do
    content = """
    ExUnit.start()
    """

    Igniter.create_or_update_elixir_file(
      igniter,
      "test/test_helper.exs",
      content,
      fn zipper -> {:ok, zipper} end
    )
  end
end
