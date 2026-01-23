defmodule Mix.Tasks.Phx.Install.DashboardTest do
  use ExUnit.Case

  import Igniter.Test

  describe "phx.install.dashboard" do
    test "adds phoenix_live_dashboard dependency" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.router")
        |> Igniter.compose_task("phx.install.dashboard")
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "mix.exs")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "phoenix_live_dashboard"
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
  end
end
