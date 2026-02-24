defmodule Mix.Tasks.Phx.Install.HeroiconsTest do
  use ExUnit.Case

  import Igniter.Test

  defp project_with_assets do
    test_project()
    |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
    |> Igniter.compose_task("phx.install.html")
    |> Igniter.compose_task("phx.install.assets")
    |> apply_igniter!()
  end

  describe "phx.install.heroicons" do
    test "declares heroicons dependency" do
      info = Mix.Tasks.Phx.Install.Heroicons.info([], nil)
      assert Enum.any?(info.adds_deps, fn dep -> elem(dep, 0) == :heroicons end)
    end

    test "creates assets/vendor/heroicons.js" do
      project_with_assets()
      |> Igniter.compose_task("phx.install.heroicons")
      |> assert_creates("assets/vendor/heroicons.js")
    end

    test "heroicons.js contains Tailwind plugin" do
      igniter =
        project_with_assets()
        |> Igniter.compose_task("phx.install.heroicons")
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "assets/vendor/heroicons.js")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "tailwindcss/plugin"
      assert content =~ "heroicons/optimized"
      assert content =~ "matchComponents"
    end

    test "appends @plugin to app.css" do
      igniter =
        project_with_assets()
        |> Igniter.compose_task("phx.install.heroicons")
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "assets/css/app.css")
      content = Rewrite.Source.get(source, :content)

      assert content =~ ~s|@plugin "../vendor/heroicons";|
    end

    test "adds icon/1 to CoreComponents" do
      igniter =
        project_with_assets()
        |> Igniter.compose_task("phx.install.heroicons")
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "lib/test_web/components/core_components.ex")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "def icon("
      assert content =~ "attr(:name, :string, required: true)"
    end

    test "is idempotent" do
      igniter =
        project_with_assets()
        |> Igniter.compose_task("phx.install.heroicons")
        |> apply_igniter!()

      igniter
      |> Igniter.compose_task("phx.install.heroicons")
      |> assert_unchanged()
    end

    test "works with custom app name" do
      igniter =
        test_project(app_name: :my_app)
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.html")
        |> Igniter.compose_task("phx.install.assets")
        |> apply_igniter!()
        |> Igniter.compose_task("phx.install.heroicons")
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "lib/my_app_web/components/core_components.ex")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "def icon("
    end
  end
end
