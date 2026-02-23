defmodule Mix.Tasks.Phx.Install.RouterTest do
  use ExUnit.Case

  import Igniter.Test

  describe "phx.install.router" do
    test "creates router module" do
      test_project()
      |> Igniter.compose_task("phx.install.router")
      |> assert_creates("lib/test_web/router.ex")
    end

    test "router has api pipeline" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.router")
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "lib/test_web/router.ex")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "use TestWeb, :router"
      assert content =~ "pipeline :api do"
      assert content =~ ~s|plug(:accepts, ["json"])|
      assert content =~ ~s|scope "/api", TestWeb do|
      assert content =~ "pipe_through(:api)"
    end

    test "creates error_json module" do
      test_project()
      |> Igniter.compose_task("phx.install.router")
      |> assert_creates("lib/test_web/error_json.ex")
    end

    test "error_json has correct structure" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.router")
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "lib/test_web/error_json.ex")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "defmodule TestWeb.ErrorJSON"
      assert content =~ "def render(template, _assigns)"
      assert content =~ "Phoenix.Controller.status_message_from_template"
    end

    test "creates conn_case test helper" do
      test_project()
      |> Igniter.compose_task("phx.install.router")
      |> assert_creates("lib/test_web/conn_case.ex")
    end

    test "conn_case has correct structure" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.router")
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "lib/test_web/conn_case.ex")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "defmodule TestWeb.ConnCase"
      assert content =~ "use ExUnit.CaseTemplate"
      assert content =~ "@endpoint TestWeb.Endpoint"
      assert content =~ "use TestWeb, :verified_routes"
      assert content =~ "import Plug.Conn"
      assert content =~ "import Phoenix.ConnTest"
      assert content =~ "Phoenix.ConnTest.build_conn()"
    end

    test "works with custom app name" do
      igniter =
        test_project(app_name: :my_app)
        |> Igniter.compose_task("phx.install.router")
        |> apply_igniter!()

      assert igniter.rewrite.sources["lib/my_app_web/router.ex"]
      assert igniter.rewrite.sources["lib/my_app_web/error_json.ex"]
      assert igniter.rewrite.sources["lib/my_app_web/conn_case.ex"]

      router_content =
        Rewrite.source!(igniter.rewrite, "lib/my_app_web/router.ex")
        |> Rewrite.Source.get(:content)

      assert router_content =~ "use MyAppWeb, :router"
      assert router_content =~ ~s|scope "/api", MyAppWeb do|
    end

    test "is idempotent" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.router")
        |> apply_igniter!()

      igniter
      |> Igniter.compose_task("phx.install.router")
      |> assert_unchanged()
    end
  end
end
