defmodule Mix.Tasks.Phx.Install.EctoTest do
  use ExUnit.Case

  import Igniter.Test

  describe "phx.install.ecto" do
    test "declares ecto_sql dependency" do
      info = Mix.Tasks.Phx.Install.Ecto.info([], nil)
      assert {:ecto_sql, "~> 3.10"} in info.adds_deps
    end

    test "declares postgrex dependency by default" do
      info = Mix.Tasks.Phx.Install.Ecto.info([], nil)
      assert Enum.any?(info.adds_deps, fn dep -> elem(dep, 0) == :postgrex end)
    end

    test "creates Repo module" do
      test_project()
      |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
      |> Igniter.compose_task("phx.install.ecto")
      |> assert_creates("lib/test/repo.ex")
    end

    test "Repo module uses Ecto.Repo" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.ecto")
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "lib/test/repo.ex")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "use Ecto.Repo"
      assert content =~ "otp_app: :test"
      assert content =~ "Ecto.Adapters.Postgres"
    end

    test "configures ecto_repos in config.exs" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.ecto")
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "config/config.exs")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "ecto_repos"
      assert content =~ "Test.Repo"
    end

    test "configures dev database" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.ecto")
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "config/dev.exs")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "Test.Repo"
      assert content =~ "username:"
      assert content =~ "postgres"
      assert content =~ "hostname:"
      assert content =~ "localhost"
      assert content =~ "test_dev"
    end

    test "configures test database" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.ecto")
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "config/test.exs")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "Test.Repo"
      assert content =~ "test_test"
      assert content =~ "Ecto.Adapters.SQL.Sandbox"
    end

    test "creates seeds.exs file" do
      test_project()
      |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
      |> Igniter.compose_task("phx.install.ecto")
      |> assert_creates("priv/repo/seeds.exs")
    end

    test "seeds.exs contains instructions" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.ecto")
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "priv/repo/seeds.exs")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "mix run priv/repo/seeds.exs"
      assert content =~ "Test.Repo.insert!"
    end

    test "creates DataCase module" do
      test_project()
      |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
      |> Igniter.compose_task("phx.install.ecto")
      |> assert_creates("test/support/data_case.ex")
    end

    test "DataCase module sets up sandbox" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.ecto")
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "test/support/data_case.ex")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "defmodule Test.DataCase"
      assert content =~ "Ecto.Adapters.SQL.Sandbox"
      assert content =~ "setup_sandbox"
      assert content =~ "errors_on"
    end

    test "adds Repo to supervision tree" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.ecto")
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "lib/test/application.ex")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "Test.Repo"
    end

    test "adds ecto aliases to mix.exs" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.ecto")
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "mix.exs")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "ecto.setup"
      assert content =~ "ecto.reset"
      assert content =~ "ecto.create"
      assert content =~ "ecto.migrate"
    end

    test "adds ecto to formatter" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.core")
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.ecto")

      source = Rewrite.source!(igniter.rewrite, ".formatter.exs")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "ecto_sql"
    end

    test "works with custom app name" do
      igniter =
        test_project(app_name: :my_app)
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.ecto")
        |> apply_igniter!()

      assert igniter.rewrite.sources["lib/my_app/repo.ex"]

      source = Rewrite.source!(igniter.rewrite, "lib/my_app/repo.ex")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "defmodule MyApp.Repo"
      assert content =~ "otp_app: :my_app"

      source = Rewrite.source!(igniter.rewrite, "config/dev.exs")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "my_app_dev"
    end

    test "supports mysql adapter" do
      info = Mix.Tasks.Phx.Install.Ecto.info(["--adapter", "mysql"], nil)
      assert Enum.any?(info.adds_deps, fn dep -> elem(dep, 0) == :myxql end)

      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.ecto", ["--adapter", "mysql"])
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "lib/test/repo.ex")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "Ecto.Adapters.MyXQL"
    end

    test "supports sqlite adapter" do
      info = Mix.Tasks.Phx.Install.Ecto.info(["--adapter", "sqlite"], nil)
      assert Enum.any?(info.adds_deps, fn dep -> elem(dep, 0) == :ecto_sqlite3 end)

      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.ecto", ["--adapter", "sqlite"])
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "lib/test/repo.ex")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "Ecto.Adapters.SQLite3"
    end

    test "running twice does not produce errors" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.ecto")
        |> apply_igniter!()

      result =
        igniter
        |> Igniter.compose_task("phx.install.ecto")

      assert result.issues == []
    end
  end
end
