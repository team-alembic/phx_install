defmodule Mix.Tasks.Phx.Install.Html.DaisyTest do
  use ExUnit.Case

  import Igniter.Test

  defp setup_project(opts \\ []) do
    app_name = Keyword.get(opts, :app_name, :test)

    test_project(app_name: app_name)
    |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
  end

  describe "phx.install.html --ui daisy" do
    test "creates CoreComponents with DaisyUI classes" do
      igniter =
        setup_project()
        |> Igniter.compose_task("phx.install.html", ["--ui", "daisy"])
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "lib/test_web/components/core_components.ex")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "use Phoenix.Component"
      assert content =~ "use Gettext, backend: TestWeb.Gettext"
      assert content =~ "toast toast-top toast-end"
      assert content =~ "alert-info"
      assert content =~ "btn-primary"
      assert content =~ "fieldset"
      assert content =~ "text-error"
    end

    test "creates Layouts with inline app/1 and flash_group/1" do
      igniter =
        setup_project()
        |> Igniter.compose_task("phx.install.html", ["--ui", "daisy"])
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "lib/test_web/components/layouts.ex")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "def app(assigns)"
      assert content =~ "def flash_group(assigns)"
      assert content =~ "def theme_toggle(assigns)"
      assert content =~ "navbar"
      assert content =~ "client-error"
      assert content =~ "server-error"
    end

    test "creates root layout with theme-switching JS" do
      igniter =
        setup_project()
        |> Igniter.compose_task("phx.install.html", ["--ui", "daisy"])
        |> apply_igniter!()

      source =
        Rewrite.source!(igniter.rewrite, "lib/test_web/components/layouts/root.html.heex")

      content = Rewrite.Source.get(source, :content)

      assert content =~ "phx:theme"
      assert content =~ "data-theme"
      assert content =~ "setTheme"
    end

    test "creates logo SVG" do
      setup_project()
      |> Igniter.compose_task("phx.install.html", ["--ui", "daisy"])
      |> assert_creates("priv/static/images/logo.svg")
    end

    test "creates phx-daisy.css with DaisyUI plugin config" do
      igniter =
        setup_project()
        |> Igniter.compose_task("phx.install.assets")
        |> Igniter.compose_task("phx.install.html", ["--ui", "daisy"])
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "assets/css/phx-daisy.css")
      content = Rewrite.Source.get(source, :content)

      assert content =~ ~s|@plugin "../vendor/daisyui"|
      assert content =~ ~s|@plugin "../vendor/daisyui-theme"|
      assert content =~ "name: \"dark\""
      assert content =~ "name: \"light\""
      assert content =~ "@custom-variant dark"
    end

    test "appends daisy CSS import to app.css" do
      igniter =
        setup_project()
        |> Igniter.compose_task("phx.install.assets")
        |> Igniter.compose_task("phx.install.html", ["--ui", "daisy"])
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "assets/css/app.css")
      content = Rewrite.Source.get(source, :content)

      assert content =~ ~s|@import "./phx-daisy.css";|
    end

    test "creates ErrorHTML module" do
      setup_project()
      |> Igniter.compose_task("phx.install.html", ["--ui", "daisy"])
      |> assert_creates("lib/test_web/controllers/error_html.ex")
    end

    test "adds html function to web module" do
      igniter =
        setup_project()
        |> Igniter.compose_task("phx.install.html", ["--ui", "daisy"])
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "lib/test_web.ex")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "def html do"
      assert content =~ "defp html_helpers do"
    end

    test "works with custom app name" do
      igniter =
        setup_project(app_name: :my_app)
        |> Igniter.compose_task("phx.install.html", ["--ui", "daisy"])
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "lib/my_app_web/components/core_components.ex")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "defmodule MyAppWeb.CoreComponents"
      assert content =~ "use Gettext, backend: MyAppWeb.Gettext"

      source = Rewrite.source!(igniter.rewrite, "lib/my_app_web/components/layouts.ex")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "use MyAppWeb, :html"
    end
  end
end
