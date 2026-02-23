defmodule Mix.Tasks.Phx.Install.EndpointTest do
  use ExUnit.Case

  import Igniter.Test

  describe "phx.install.endpoint" do
    test "adds required dependencies" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint")

      igniter
      |> assert_has_patch("mix.exs", """
      + | {:bandit, "~> 1.5"}
      """)

      igniter
      |> assert_has_patch("mix.exs", """
      + | {:dns_cluster, "~> 0.1"}
      """)

      igniter
      |> assert_has_patch("mix.exs", """
      + | {:telemetry_metrics, "~> 1.0"}
      """)

      igniter
      |> assert_has_patch("mix.exs", """
      + | {:telemetry_poller, "~> 1.0"}
      """)
    end

    test "creates web module" do
      test_project()
      |> Igniter.compose_task("phx.install.endpoint")
      |> assert_creates("lib/test_web.ex")
    end

    test "web module has correct structure" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint")
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "lib/test_web.ex")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "def static_paths"
      assert content =~ "def router"
      assert content =~ "def channel"
      assert content =~ "def controller"
      assert content =~ "def verified_routes"
      assert content =~ "defmacro __using__"
      assert content =~ "Phoenix.VerifiedRoutes"
      assert content =~ "TestWeb.Router"
    end

    test "creates telemetry module" do
      test_project()
      |> Igniter.compose_task("phx.install.endpoint")
      |> assert_creates("lib/test_web/telemetry.ex")
    end

    test "telemetry module has correct structure" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint")
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "lib/test_web/telemetry.ex")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "use Supervisor"
      assert content =~ "import Telemetry.Metrics"
      assert content =~ "def start_link"
      assert content =~ "def metrics"
      assert content =~ "phoenix.endpoint"
      assert content =~ "phoenix.router_dispatch"
      assert content =~ "vm.memory.total"
    end

    test "creates endpoint module" do
      test_project()
      |> Igniter.compose_task("phx.install.endpoint")
      |> assert_creates("lib/test_web/endpoint.ex")
    end

    test "endpoint module has correct structure" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint")
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "lib/test_web/endpoint.ex")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "use Phoenix.Endpoint, otp_app: :test"
      assert content =~ "@session_options"
      assert content =~ "signing_salt:"
      assert content =~ "plug(Plug.Static"
      assert content =~ "plug(Phoenix.CodeReloader)"
      assert content =~ "plug(Plug.RequestId)"
      assert content =~ "plug(Plug.Telemetry"
      assert content =~ "plug(Plug.Parsers"
      assert content =~ "plug(Plug.Session"
      assert content =~ "plug(TestWeb.Router)"
    end

    test "works with custom app name" do
      igniter =
        test_project(app_name: :my_app)
        |> Igniter.compose_task("phx.install.endpoint")
        |> apply_igniter!()

      assert igniter.rewrite.sources["lib/my_app_web.ex"]
      assert igniter.rewrite.sources["lib/my_app_web/telemetry.ex"]
      assert igniter.rewrite.sources["lib/my_app_web/endpoint.ex"]

      endpoint_content =
        Rewrite.source!(igniter.rewrite, "lib/my_app_web/endpoint.ex")
        |> Rewrite.Source.get(:content)

      assert endpoint_content =~ "otp_app: :my_app"
      assert endpoint_content =~ "plug(MyAppWeb.Router)"
    end

    test "uses provided session signing salt" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint", [
          "--session-signing-salt",
          "my_custom_salt"
        ])
        |> apply_igniter!()

      endpoint_content =
        Rewrite.source!(igniter.rewrite, "lib/test_web/endpoint.ex")
        |> Rewrite.Source.get(:content)

      assert endpoint_content =~ "my_custom_salt"
    end

    test "is idempotent when session signing salt is provided" do
      args = ["--session-signing-salt", "test_salt"]

      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint", args)
        |> apply_igniter!()

      igniter
      |> Igniter.compose_task("phx.install.endpoint", args)
      |> assert_unchanged()
    end
  end
end
