defmodule Mix.Tasks.Phx.Install.PageTest do
  use ExUnit.Case

  import Igniter.Test

  defp setup_project(opts \\ []) do
    app_name = Keyword.get(opts, :app_name, :test)

    test_project(app_name: app_name)
    |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
    |> Igniter.compose_task("phx.install.html", ["--ui", "tailwind"])
    |> Igniter.compose_task("phx.install.router")
  end

  describe "phx.install.page" do
    test "creates PageController module" do
      setup_project()
      |> Igniter.compose_task("phx.install.page")
      |> assert_creates("lib/test_web/controllers/page_controller.ex")
    end

    test "PageController has home action" do
      igniter =
        setup_project()
        |> Igniter.compose_task("phx.install.page")
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "lib/test_web/controllers/page_controller.ex")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "use TestWeb, :controller"
      assert content =~ "def home(conn, _params)"
      assert content =~ "render(conn, :home)"
    end

    test "creates PageHTML module" do
      setup_project()
      |> Igniter.compose_task("phx.install.page")
      |> assert_creates("lib/test_web/controllers/page_html.ex")
    end

    test "PageHTML embeds templates" do
      igniter =
        setup_project()
        |> Igniter.compose_task("phx.install.page")
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "lib/test_web/controllers/page_html.ex")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "use TestWeb, :html"
      assert content =~ ~s|embed_templates("page_html/*")|
    end

    test "creates home.html.heex template" do
      setup_project()
      |> Igniter.compose_task("phx.install.page")
      |> assert_creates("lib/test_web/controllers/page_html/home.html.heex")
    end

    test "home template has Phoenix content" do
      igniter =
        setup_project()
        |> Igniter.compose_task("phx.install.page")
        |> apply_igniter!()

      source =
        Rewrite.source!(igniter.rewrite, "lib/test_web/controllers/page_html/home.html.heex")

      content = Rewrite.Source.get(source, :content)

      assert content =~ "Phoenix Framework"
      assert content =~ "Peace of mind from prototype to production"
      assert content =~ "flash_group"
    end

    test "adds browser scope with root route to router" do
      igniter =
        setup_project()
        |> Igniter.compose_task("phx.install.page")
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "lib/test_web/router.ex")
      content = Rewrite.Source.get(source, :content)

      assert content =~ ~s|scope "/", TestWeb do|
      assert content =~ "pipe_through(:browser)"
      assert content =~ ~s|get("/", PageController, :home)|
    end

    test "works with custom app name" do
      igniter =
        setup_project(app_name: :my_app)
        |> Igniter.compose_task("phx.install.page")
        |> apply_igniter!()

      assert igniter.rewrite.sources["lib/my_app_web/controllers/page_controller.ex"]
      assert igniter.rewrite.sources["lib/my_app_web/controllers/page_html.ex"]
      assert igniter.rewrite.sources["lib/my_app_web/controllers/page_html/home.html.heex"]

      controller_content =
        Rewrite.source!(igniter.rewrite, "lib/my_app_web/controllers/page_controller.ex")
        |> Rewrite.Source.get(:content)

      assert controller_content =~ "defmodule MyAppWeb.PageController"

      router_content =
        Rewrite.source!(igniter.rewrite, "lib/my_app_web/router.ex")
        |> Rewrite.Source.get(:content)

      assert router_content =~ ~s|scope "/", MyAppWeb do|
    end

    test "is idempotent" do
      igniter =
        setup_project()
        |> Igniter.compose_task("phx.install.page")
        |> apply_igniter!()

      igniter
      |> Igniter.compose_task("phx.install.page")
      |> assert_unchanged()
    end
  end
end
