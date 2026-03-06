defmodule Mix.Tasks.Phx.Install.Endpoint do
  @shortdoc "Installs Phoenix Endpoint, Telemetry, and web module"
  @moduledoc """
  Installs Phoenix Endpoint, Telemetry, and web module.

  This task sets up:
  - `lib/<app>_web/endpoint.ex` - Phoenix.Endpoint with standard plugs
  - `lib/<app>_web/telemetry.ex` - Telemetry supervisor with metrics
  - `lib/<app>_web.ex` - Web module with controller/channel/verified_routes macros

  ## Usage

      mix phx.install.endpoint

  ## Options

  - `--session-signing-salt` - Salt for signing session cookies (generated if not provided)

  This task is typically called by `mix phx.install` rather than directly.
  """
  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :phoenix,
      example: "mix phx.install.endpoint",
      adds_deps: [
        {:bandit, "~> 1.5"},
        {:dns_cluster, "~> 0.1"},
        {:telemetry_metrics, "~> 1.0"},
        {:telemetry_poller, "~> 1.0"}
      ],
      schema: [
        session_signing_salt: :string
      ],
      composes: ["phx.install.core", "phx.install.router"]
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    app_name = Igniter.Project.Application.app_name(igniter)
    web_module = Igniter.Libs.Phoenix.web_module(igniter)
    endpoint_module = Module.concat(web_module, Endpoint)

    opts = igniter.args.options
    session_signing_salt = opts[:session_signing_salt] || PhxInstall.random_string(8)

    igniter
    |> Igniter.Project.Deps.add_dep({:phoenix, "~> 1.7"})
    |> Igniter.Project.Deps.add_dep({:bandit, "~> 1.5"})
    |> Igniter.Project.Deps.add_dep({:dns_cluster, "~> 0.1"})
    |> Igniter.Project.Deps.add_dep({:telemetry_metrics, "~> 1.0"})
    |> Igniter.Project.Deps.add_dep({:telemetry_poller, "~> 1.0"})
    |> Igniter.compose_task("phx.install.core")
    |> Igniter.compose_task("phx.install.router")
    |> create_web_module(app_name, web_module, endpoint_module)
    |> create_telemetry_module(web_module)
    |> create_endpoint_module(app_name, web_module, endpoint_module, session_signing_salt)
  end

  defp create_web_module(igniter, _app_name, web_module, endpoint_module) do
    Igniter.Project.Module.find_and_update_or_create_module(
      igniter,
      web_module,
      """
      @moduledoc \"\"\"
      The entrypoint for defining your web interface, such
      as controllers, components, channels, and so on.

      This can be used in your application as:

          use #{inspect(web_module)}, :controller

      The definitions below will be executed for every controller,
      component, etc, so keep them short and clean, focused
      on imports, uses and aliases.

      Do NOT define functions inside the quoted expressions
      below. Instead, define additional modules and import
      those modules here.
      \"\"\"

      def static_paths, do: ~w(assets fonts images favicon.ico robots.txt)

      def router do
        quote do
          use Phoenix.Router, helpers: false

          import Plug.Conn
          import Phoenix.Controller
        end
      end

      def channel do
        quote do
          use Phoenix.Channel
        end
      end

      def controller do
        quote do
          use Phoenix.Controller, formats: [:html, :json]

          import Plug.Conn

          unquote(verified_routes())
        end
      end

      def verified_routes do
        quote do
          use Phoenix.VerifiedRoutes,
            endpoint: #{inspect(endpoint_module)},
            router: #{inspect(Module.concat(web_module, :Router))},
            statics: #{inspect(web_module)}.static_paths()
        end
      end

      @doc \"\"\"
      When used, dispatch to the appropriate controller/live_view/etc.
      \"\"\"
      defmacro __using__(which) when is_atom(which) do
        apply(__MODULE__, which, [])
      end
      """,
      fn zipper -> {:ok, zipper} end
    )
  end

  defp create_telemetry_module(igniter, web_module) do
    telemetry_module = Module.concat(web_module, Telemetry)

    Igniter.Project.Module.find_and_update_or_create_module(
      igniter,
      telemetry_module,
      """
      use Supervisor
      import Telemetry.Metrics

      def start_link(arg) do
        Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
      end

      @impl true
      def init(_arg) do
        children = [
          {:telemetry_poller, measurements: periodic_measurements(), period: 10_000}
        ]

        Supervisor.init(children, strategy: :one_for_one)
      end

      def metrics do
        [
          summary("phoenix.endpoint.start.system_time",
            unit: {:native, :millisecond}
          ),
          summary("phoenix.endpoint.stop.duration",
            unit: {:native, :millisecond}
          ),
          summary("phoenix.router_dispatch.start.system_time",
            tags: [:route],
            unit: {:native, :millisecond}
          ),
          summary("phoenix.router_dispatch.exception.duration",
            tags: [:route],
            unit: {:native, :millisecond}
          ),
          summary("phoenix.router_dispatch.stop.duration",
            tags: [:route],
            unit: {:native, :millisecond}
          ),
          summary("phoenix.socket_connected.duration",
            unit: {:native, :millisecond}
          ),
          sum("phoenix.socket_drain.count"),
          summary("phoenix.channel_joined.duration",
            unit: {:native, :millisecond}
          ),
          summary("phoenix.channel_handled_in.duration",
            tags: [:event],
            unit: {:native, :millisecond}
          ),

          summary("vm.memory.total", unit: {:byte, :kilobyte}),
          summary("vm.total_run_queue_lengths.total"),
          summary("vm.total_run_queue_lengths.cpu"),
          summary("vm.total_run_queue_lengths.io")
        ]
      end

      defp periodic_measurements do
        []
      end
      """,
      fn zipper -> {:ok, zipper} end
    )
  end

  defp create_endpoint_module(
         igniter,
         app_name,
         web_module,
         endpoint_module,
         session_signing_salt
       ) do
    Igniter.Project.Module.find_and_update_or_create_module(
      igniter,
      endpoint_module,
      """
      use Phoenix.Endpoint, otp_app: #{inspect(app_name)}

      @session_options [
        store: :cookie,
        key: "_#{app_name}_key",
        signing_salt: #{inspect(session_signing_salt)},
        same_site: "Lax"
      ]

      plug Plug.Static,
        at: "/",
        from: #{inspect(app_name)},
        gzip: not code_reloading?,
        only: #{inspect(web_module)}.static_paths(),
        raise_on_missing_only: code_reloading?

      if code_reloading? do
        plug Phoenix.CodeReloader
      end

      plug Plug.RequestId
      plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

      plug Plug.Parsers,
        parsers: [:urlencoded, :multipart, :json],
        pass: ["*/*"],
        json_decoder: Phoenix.json_library()

      plug Plug.MethodOverride
      plug Plug.Head
      plug Plug.Session, @session_options
      plug #{inspect(Module.concat(web_module, :Router))}
      """,
      fn zipper -> {:ok, zipper} end
    )
  end
end
