defmodule Mix.Tasks.Phx.Install.Ecto do
  @moduledoc """
  Adds Ecto database support to a Phoenix application.

  This task sets up:
  - `ecto_sql` and `postgrex` dependencies
  - `lib/<app>/repo.ex` - Ecto Repo module
  - Database configuration in dev.exs, test.exs, and runtime.exs
  - `priv/repo/seeds.exs` - Database seed script
  - `test/support/data_case.ex` - Test case for database tests
  - Adds Repo to the application supervision tree
  - Mix aliases for ecto.setup, ecto.reset, and test

  ## Usage

      mix phx.install.ecto

  ## Options

  - `--adapter` - The database adapter to use (postgres, mysql, sqlite). Default: postgres

  This task is typically called by `mix phx.install` rather than directly.
  """
  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :phoenix,
      example: "mix phx.install.ecto",
      schema: [
        adapter: :string
      ],
      defaults: [
        adapter: "postgres"
      ]
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    app_name = Igniter.Project.Application.app_name(igniter)

    app_module = Igniter.Project.Module.module_name_prefix(igniter)

    repo_module = Module.concat(app_module, Repo)

    adapter = igniter.args.options[:adapter] || "postgres"
    {adapter_module, adapter_dep} = adapter_config(adapter)

    igniter
    |> Igniter.Project.Deps.add_dep({:ecto_sql, "~> 3.10"})
    |> Igniter.Project.Deps.add_dep(adapter_dep)
    |> create_repo_module(app_name, app_module, adapter_module)
    |> configure_ecto_repos(app_name, repo_module)
    |> configure_dev_database(app_name, repo_module, adapter)
    |> configure_test_database(app_name, app_module, repo_module, adapter)
    |> configure_prod_database(app_name, repo_module, adapter)
    |> create_seeds_file(app_module)
    |> create_data_case(app_module, repo_module)
    |> add_repo_to_supervision_tree(app_module, repo_module)
    |> update_conn_case_for_ecto(app_module)
    |> add_ecto_aliases()
    |> add_ecto_to_formatter()
  end

  defp adapter_config("postgres") do
    {Ecto.Adapters.Postgres, {:postgrex, ">= 0.0.0"}}
  end

  defp adapter_config("mysql") do
    {Ecto.Adapters.MyXQL, {:myxql, ">= 0.0.0"}}
  end

  defp adapter_config("sqlite") do
    {Ecto.Adapters.SQLite3, {:ecto_sqlite3, ">= 0.0.0"}}
  end

  defp adapter_config(_), do: adapter_config("postgres")

  defp create_repo_module(igniter, app_name, app_module, adapter_module) do
    repo_module = Module.concat(app_module, Repo)

    Igniter.Project.Module.find_and_update_or_create_module(
      igniter,
      repo_module,
      """
      use Ecto.Repo,
        otp_app: #{inspect(app_name)},
        adapter: #{inspect(adapter_module)}
      """,
      fn zipper -> {:ok, zipper} end
    )
  end

  defp configure_ecto_repos(igniter, app_name, repo_module) do
    Igniter.Project.Config.configure(
      igniter,
      "config.exs",
      app_name,
      [:ecto_repos],
      [repo_module],
      updater: fn zipper ->
        case Igniter.Code.List.prepend_new_to_list(zipper, repo_module) do
          {:ok, zipper} -> {:ok, zipper}
          :error -> {:ok, zipper}
        end
      end
    )
  end

  defp configure_dev_database(igniter, app_name, repo_module, "sqlite") do
    config_code =
      Sourceror.parse_string!("""
      [
        database: Path.expand("../#{app_name}_dev.db", __DIR__),
        pool_size: 5,
        stacktrace: true,
        show_sensitive_data_on_connection_error: true
      ]
      """)

    Igniter.Project.Config.configure(
      igniter,
      "dev.exs",
      app_name,
      [repo_module],
      {:code, config_code},
      updater: fn zipper -> {:ok, zipper} end
    )
  end

  defp configure_dev_database(igniter, app_name, repo_module, _adapter) do
    config = [
      username: "postgres",
      password: "postgres",
      hostname: "localhost",
      database: "#{app_name}_dev",
      stacktrace: true,
      show_sensitive_data_on_connection_error: true,
      pool_size: 10
    ]

    Igniter.Project.Config.configure(
      igniter,
      "dev.exs",
      app_name,
      [repo_module],
      config,
      updater: fn zipper -> {:ok, zipper} end
    )
  end

  defp configure_test_database(igniter, app_name, _app_module, repo_module, "sqlite") do
    config_code =
      Sourceror.parse_string!("""
      [
        database: Path.expand("../#{app_name}_test.db", __DIR__),
        pool_size: 5,
        pool: Ecto.Adapters.SQL.Sandbox
      ]
      """)

    igniter
    |> Igniter.Project.Config.configure(
      "test.exs",
      app_name,
      [repo_module],
      {:code, config_code},
      updater: fn zipper -> {:ok, zipper} end
    )
  end

  defp configure_test_database(igniter, app_name, _app_module, repo_module, _adapter) do
    config_code =
      Sourceror.parse_string!(~s"""
      [
        username: "postgres",
        password: "postgres",
        hostname: "localhost",
        database: "#{app_name}_test\#{System.get_env("MIX_TEST_PARTITION")}",
        pool: Ecto.Adapters.SQL.Sandbox,
        pool_size: System.schedulers_online() * 2
      ]
      """)

    igniter
    |> Igniter.Project.Config.configure(
      "test.exs",
      app_name,
      [repo_module],
      {:code, config_code},
      updater: fn zipper -> {:ok, zipper} end
    )
  end

  defp configure_prod_database(igniter, app_name, repo_module, "sqlite") do
    db_code = """
    database_path =
      System.get_env("DATABASE_PATH") ||
        raise \"""
        environment variable DATABASE_PATH is missing.
        For example: /etc/#{app_name}/#{app_name}.db
        \"""

    config #{inspect(app_name)}, #{inspect(repo_module)},
      database: database_path,
      pool_size: String.to_integer(System.get_env("POOL_SIZE") || "5")
    """

    add_code_to_prod_block(igniter, db_code, repo_module)
  end

  defp configure_prod_database(igniter, app_name, repo_module, _adapter) do
    db_code = """
    database_url =
      System.get_env("DATABASE_URL") ||
        raise \"""
        environment variable DATABASE_URL is missing.
        For example: ecto://USER:PASS@HOST/DATABASE
        \"""

    maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

    config #{inspect(app_name)}, #{inspect(repo_module)},
      url: database_url,
      pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
      socket_options: maybe_ipv6
    """

    add_code_to_prod_block(igniter, db_code, repo_module)
  end

  defp add_code_to_prod_block(igniter, db_code, repo_module) do
    prod_block = """
    import Config

    if config_env() == :prod do
      #{db_code}
    end
    """

    Igniter.create_or_update_elixir_file(
      igniter,
      "config/runtime.exs",
      prod_block,
      &insert_db_code_into_runtime(&1, db_code, repo_module)
    )
  end

  defp insert_db_code_into_runtime(zipper, db_code, repo_module) do
    if has_repo_config?(zipper, repo_module) do
      {:ok, zipper}
    else
      insert_db_code_into_prod_block(zipper, db_code)
    end
  end

  defp insert_db_code_into_prod_block(zipper, db_code) do
    case find_prod_block(zipper) do
      {:ok, prod_zipper} ->
        case Igniter.Code.Common.move_to_do_block(prod_zipper) do
          {:ok, body_zipper} ->
            {:ok, Igniter.Code.Common.add_code(body_zipper, db_code)}

          :error ->
            {:ok, Igniter.Code.Common.add_code(prod_zipper, db_code)}
        end

      :error ->
        {:ok, Igniter.Code.Common.add_code(zipper, db_code)}
    end
  end

  defp has_repo_config?(zipper, repo_module) do
    case Igniter.Code.Function.move_to_function_call(
           zipper,
           :config,
           [3, 4],
           &Igniter.Code.Function.argument_equals?(&1, 1, repo_module)
         ) do
      {:ok, _} -> true
      :error -> false
    end
  end

  defp find_prod_block(zipper) do
    Igniter.Code.Common.move_to(zipper, fn z ->
      case Sourceror.Zipper.node(z) do
        {:if, _, [{:==, _, [{:config_env, _, _}, {:__block__, _, [:prod]}]} | _]} -> true
        {:if, _, [{:==, _, [{:config_env, _, _}, :prod]} | _]} -> true
        _ -> false
      end
    end)
  end

  defp create_seeds_file(igniter, app_module) do
    content = """
    # Script for populating the database. You can run it as:
    #
    #     mix run priv/repo/seeds.exs
    #
    # Inside the script, you can read and write to any of your
    # repositories directly:
    #
    #     #{inspect(app_module)}.Repo.insert!(%#{inspect(app_module)}.SomeSchema{})
    #
    # We recommend using the bang functions (`insert!`, `update!`
    # and so on) as they will fail if something goes wrong.
    """

    Igniter.create_new_file(igniter, "priv/repo/seeds.exs", content, on_exists: :skip)
  end

  defp create_data_case(igniter, app_module, repo_module) do
    data_case_module = Module.concat(app_module, DataCase)

    Igniter.Project.Module.find_and_update_or_create_module(
      igniter,
      data_case_module,
      """
      @moduledoc \"""
      This module defines the setup for tests requiring
      access to the application's data layer.

      You may define functions here to be used as helpers in
      your tests.

      Finally, if the test case interacts with the database,
      we enable the SQL sandbox, so changes done to the database
      are reverted at the end of every test. If you are using
      PostgreSQL, you can even run database tests asynchronously
      by setting `use #{inspect(data_case_module)}, async: true`, although
      this option is not recommended for other databases.
      \"""

      use ExUnit.CaseTemplate

      using do
        quote do
          alias #{inspect(repo_module)}

          import Ecto
          import Ecto.Changeset
          import Ecto.Query
          import #{inspect(data_case_module)}
        end
      end

      setup tags do
        #{inspect(data_case_module)}.setup_sandbox(tags)
        :ok
      end

      @doc \"""
      Sets up the sandbox based on the test tags.
      \"""
      def setup_sandbox(tags) do
        pid = Ecto.Adapters.SQL.Sandbox.start_owner!(#{inspect(repo_module)}, shared: not tags[:async])
        on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
      end

      @doc \"""
      A helper that transforms changeset errors into a map of messages.

          assert {:error, changeset} = Accounts.create_user(%{password: "short"})
          assert "password is too short" in errors_on(changeset).password
          assert %{password: ["password is too short"]} = errors_on(changeset)

      \"""
      def errors_on(changeset) do
        Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
          Regex.replace(~r"%{(\\w+)}", message, fn _, key ->
            opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
          end)
        end)
      end
      """,
      fn zipper -> {:ok, zipper} end,
      path: Igniter.Project.Module.proper_location(igniter, data_case_module, :test_support)
    )
  end

  defp add_repo_to_supervision_tree(igniter, _app_module, repo_module) do
    Igniter.Project.Application.add_new_child(
      igniter,
      repo_module,
      after: fn existing ->
        case existing do
          {module, _} when is_atom(module) ->
            String.ends_with?(Atom.to_string(module), "Telemetry")

          module when is_atom(module) ->
            String.ends_with?(Atom.to_string(module), "Telemetry")

          _ ->
            false
        end
      end
    )
  end

  defp update_conn_case_for_ecto(igniter, app_module) do
    web_module = Igniter.Libs.Phoenix.web_module(igniter)
    conn_case_module = Module.concat(web_module, ConnCase)
    data_case_module = Module.concat(app_module, DataCase)
    setup_code = "#{inspect(data_case_module)}.setup_sandbox(tags)"

    case Igniter.Project.Module.find_and_update_module(
           igniter,
           conn_case_module,
           &add_sandbox_setup_to_conn_case(&1, setup_code)
         ) do
      {:ok, igniter} -> igniter
      {:error, igniter} -> igniter
    end
  end

  defp add_sandbox_setup_to_conn_case(zipper, setup_code) do
    case Igniter.Code.Common.move_to(zipper, &setup_sandbox_call?/1) do
      {:ok, _} ->
        {:ok, zipper}

      :error ->
        case Igniter.Code.Function.move_to_def(zipper, :setup, 1) do
          {:ok, setup_zipper} ->
            {:ok, Igniter.Code.Common.add_code(setup_zipper, setup_code)}

          :error ->
            {:ok, zipper}
        end
    end
  end

  defp setup_sandbox_call?(zipper) do
    case Sourceror.Zipper.node(zipper) do
      {{:., _, [{:__aliases__, _, _}, :setup_sandbox]}, _, _} -> true
      _ -> false
    end
  end

  defp add_ecto_aliases(igniter) do
    igniter
    |> Igniter.Project.TaskAliases.add_alias(
      "ecto.setup",
      ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"]
    )
    |> Igniter.Project.TaskAliases.add_alias("ecto.reset", ["ecto.drop", "ecto.setup"])
    |> Igniter.Project.TaskAliases.add_alias(
      "test",
      ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      if_exists: {:prepend, ["ecto.create --quiet", "ecto.migrate --quiet"]}
    )
    |> Igniter.Project.TaskAliases.add_alias(
      "setup",
      ["deps.get", "ecto.setup"],
      if_exists: {:append, "ecto.setup"}
    )
  end

  defp add_ecto_to_formatter(igniter) do
    Igniter.Project.Formatter.import_dep(igniter, :ecto_sql)
  end
end
