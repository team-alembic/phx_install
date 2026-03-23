defmodule Mix.Tasks.Phx.Install.DashboardTest do
  use ExUnit.Case

  import Igniter.Test

  describe "phx.install.dashboard" do
    test "declares phoenix_live_dashboard dependency" do
      info = Mix.Tasks.Phx.Install.Dashboard.info([], nil)
      assert {:phoenix_live_dashboard, "~> 0.8"} in info.adds_deps
    end

    test "adds live_dashboard route to router" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.router")
        |> Igniter.compose_task("phx.install.dashboard")
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "lib/test_web/router.ex")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "live_dashboard"
      assert content =~ ~s|"/dashboard"|
    end

    test "adds Phoenix.LiveDashboard.Router import" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.router")
        |> Igniter.compose_task("phx.install.dashboard")
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "lib/test_web/router.ex")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "import Phoenix.LiveDashboard.Router"
    end

    test "uses dev_routes guard" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.router")
        |> Igniter.compose_task("phx.install.dashboard")
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "lib/test_web/router.ex")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "compile_env"
      assert content =~ ":dev_routes"
    end

    test "adds /dev scope with browser pipeline" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.router")
        |> Igniter.compose_task("phx.install.dashboard")
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "lib/test_web/router.ex")
      content = Rewrite.Source.get(source, :content)

      assert content =~ ~s|scope "/dev"|
      # Formatter may convert to pipe_through(:browser)
      assert content =~ "pipe_through" and content =~ ":browser"
    end

    test "references Telemetry module for metrics" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.router")
        |> Igniter.compose_task("phx.install.dashboard")
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "lib/test_web/router.ex")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "metrics: TestWeb.Telemetry"
    end

    test "works with custom app name" do
      igniter =
        test_project(app_name: :my_app)
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.router")
        |> Igniter.compose_task("phx.install.dashboard")
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "lib/my_app_web/router.ex")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "live_dashboard"
      assert content =~ "compile_env(:my_app"
      assert content =~ "metrics: MyAppWeb.Telemetry"
    end

    test "running twice does not produce errors" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.router")
        |> Igniter.compose_task("phx.install.dashboard")
        |> apply_igniter!()

      result =
        igniter
        |> Igniter.compose_task("phx.install.dashboard")

      assert result.issues == []
    end

    test "standalone invocation composes prerequisites and adds browser pipeline" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.dashboard", ["--session-signing-salt", "sessionsalt"])
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "lib/test_web/router.ex")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "pipeline :browser"
      assert content =~ "pipe_through" and content =~ ":browser"
      assert content =~ "live_dashboard"
    end

    test "adds live_dashboard into existing dev_routes block" do
      dev_routes_block = """
      if Application.compile_env(:test, :dev_routes) do
        scope "/dev" do
          pipe_through :browser
        end
      end
      """

      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.router")
        |> apply_igniter!()
        |> Igniter.Project.Module.find_and_update_module!(
          TestWeb.Router,
          fn zipper ->
            {:ok, Igniter.Code.Common.add_code(zipper, dev_routes_block)}
          end
        )
        |> apply_igniter!()
        |> Igniter.compose_task("phx.install.dashboard")
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "lib/test_web/router.ex")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "live_dashboard"
      assert content =~ "import Phoenix.LiveDashboard.Router"

      occurrences =
        content
        |> String.split("dev_routes")
        |> length()

      assert occurrences == 2, "expected exactly one dev_routes block, found #{occurrences - 1}"
    end
  end
end
