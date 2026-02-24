defmodule Mix.Tasks.Phx.Install.HtmlTest do
  use ExUnit.Case

  import Igniter.Test

  describe "phx.install.html" do
    test "declares phoenix_html dependency" do
      info = Mix.Tasks.Phx.Install.Html.info([], nil)
      assert {:phoenix_html, "~> 4.1"} in info.adds_deps
    end

    test "creates CoreComponents module" do
      test_project()
      |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
      |> Igniter.compose_task("phx.install.html")
      |> assert_creates("lib/test_web/components/core_components.ex")
    end

    test "CoreComponents has flash component" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.html")
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "lib/test_web/components/core_components.ex")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "def flash(assigns)"
      assert content =~ "use Phoenix.Component"
    end

    test "creates Layouts module" do
      test_project()
      |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
      |> Igniter.compose_task("phx.install.html")
      |> assert_creates("lib/test_web/components/layouts.ex")
    end

    test "Layouts module embeds templates" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.html")
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "lib/test_web/components/layouts.ex")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "use TestWeb, :html"
      assert content =~ ~s|embed_templates("layouts/*")|
    end

    test "creates root.html.heex layout" do
      test_project()
      |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
      |> Igniter.compose_task("phx.install.html")
      |> assert_creates("lib/test_web/components/layouts/root.html.heex")
    end

    test "creates app.html.heex layout" do
      test_project()
      |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
      |> Igniter.compose_task("phx.install.html")
      |> assert_creates("lib/test_web/components/layouts/app.html.heex")
    end

    test "creates ErrorHTML module" do
      test_project()
      |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
      |> Igniter.compose_task("phx.install.html")
      |> assert_creates("lib/test_web/controllers/error_html.ex")
    end

    test "ErrorHTML uses html macro" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.html")
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "lib/test_web/controllers/error_html.ex")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "use TestWeb, :html"
      assert content =~ "def render(template, _assigns)"
    end

    test "adds html function to web module" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.html")
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "lib/test_web.ex")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "def html do"
      assert content =~ "use Phoenix.Component"
    end

    test "adds html_helpers function to web module" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.html")
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "lib/test_web.ex")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "defp html_helpers do"
      assert content =~ "import Phoenix.HTML"
      assert content =~ "import TestWeb.CoreComponents"
      assert content =~ "alias TestWeb.Layouts"
    end

    test "works with custom app name" do
      igniter =
        test_project(app_name: :my_app)
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.html")
        |> apply_igniter!()

      assert igniter.rewrite.sources["lib/my_app_web/components/core_components.ex"]
      assert igniter.rewrite.sources["lib/my_app_web/components/layouts.ex"]
      assert igniter.rewrite.sources["lib/my_app_web/controllers/error_html.ex"]

      source = Rewrite.source!(igniter.rewrite, "lib/my_app_web/components/core_components.ex")
      content = Rewrite.Source.get(source, :content)
      assert content =~ "defmodule MyAppWeb.CoreComponents"

      source = Rewrite.source!(igniter.rewrite, "lib/my_app_web.ex")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "import MyAppWeb.CoreComponents"
    end

    test "is idempotent" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.html")
        |> apply_igniter!()

      igniter
      |> Igniter.compose_task("phx.install.html")
      |> assert_unchanged()
    end
  end
end
