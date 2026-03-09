defmodule Mix.Tasks.Phx.Install.AssetsTest do
  use ExUnit.Case

  import Igniter.Test

  describe "phx.install.assets with esbuild (default)" do
    test "creates app.js and topbar.js" do
      test_project()
      |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
      |> Igniter.compose_task("phx.install.assets")
      |> assert_creates("assets/js/app.js")
    end

    test "creates app.css" do
      test_project()
      |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
      |> Igniter.compose_task("phx.install.assets")
      |> assert_creates("assets/css/app.css")
    end

    test "creates static files" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.assets")

      igniter |> assert_creates("priv/static/robots.txt")
      igniter |> assert_creates("priv/static/favicon.ico")
    end

    test "configures esbuild in config.exs" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.assets")
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "config/config.exs")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "config :esbuild"
      assert content =~ "js/app.js"
    end

    test "configures tailwind in config.exs" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.assets")
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "config/config.exs")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "config :tailwind"
      assert content =~ "app.css"
    end

    test "configures watchers in dev.exs" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.assets")
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "config/dev.exs")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "watchers:"
      assert content =~ "esbuild:"
      assert content =~ "tailwind:"
    end

    test "configures live_reload in dev.exs" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.assets")
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "config/dev.exs")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "live_reload:"
      assert content =~ "patterns:"
    end

    test "adds asset aliases to mix.exs" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.assets")
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "mix.exs")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "assets.setup"
      assert content =~ "assets.build"
      assert content =~ "assets.deploy"
    end

    test "works with custom app name" do
      igniter =
        test_project(app_name: :my_app)
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.assets")
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "config/config.exs")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "my_app:"

      source = Rewrite.source!(igniter.rewrite, "assets/css/app.css")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "my_app_web"
    end

    test "running twice does not produce errors" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.assets")
        |> apply_igniter!()

      result = Igniter.compose_task(igniter, "phx.install.assets")

      assert result.issues == []
    end
  end

  describe "phx.install.assets --no-tailwind" do
    test "skips tailwind configuration" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.assets", ["--no-tailwind"])
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "config/config.exs")
      content = Rewrite.Source.get(source, :content)

      refute content =~ "config :tailwind"
      refute Map.has_key?(igniter.rewrite.sources, "assets/css/app.css")
    end

    test "still creates JS assets" do
      test_project()
      |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
      |> Igniter.compose_task("phx.install.assets", ["--no-tailwind"])
      |> assert_creates("assets/js/app.js")
    end
  end

  describe "phx.install.assets --lang ts" do
    test "creates app.ts instead of app.js" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.assets", ["--lang", "ts"])
        |> apply_igniter!()

      assert Map.has_key?(igniter.rewrite.sources, "assets/js/app.ts")
      refute Map.has_key?(igniter.rewrite.sources, "assets/js/app.js")
    end

    test "configures esbuild to use .ts entry point" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.assets", ["--lang", "ts"])
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "config/config.exs")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "js/app.ts"
    end
  end

  describe "phx.install.assets --bundler bun" do
    test "uses bun instead of esbuild" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.assets", ["--bundler", "bun"])
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "config/config.exs")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "config :bun"
      refute content =~ "config :esbuild"
    end

    test "creates package.json" do
      test_project()
      |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
      |> Igniter.compose_task("phx.install.assets", ["--bundler", "bun"])
      |> assert_creates("assets/package.json")
    end

    test "package.json includes workspace deps and tailwind" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.assets", ["--bundler", "bun"])
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "assets/package.json")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "phoenix"
      assert content =~ "phoenix_live_view"
      assert content =~ "topbar"
      assert content =~ "tailwindcss"
    end

    test "does not vendor topbar.js" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.assets", ["--bundler", "bun"])
        |> apply_igniter!()

      refute Map.has_key?(igniter.rewrite.sources, "assets/vendor/topbar.js")
    end

    test "app.js imports topbar from npm" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.assets", ["--bundler", "bun"])
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "assets/js/app.js")
      content = Rewrite.Source.get(source, :content)

      assert content =~ ~s(import topbar from "topbar")
      refute content =~ "vendor/topbar"
    end

    test "configures bun watchers" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.assets", ["--bundler", "bun"])
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "config/dev.exs")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "bun_js:"
      assert content =~ "bun_css:"
    end

    test "uses bun-style aliases" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.assets", ["--bundler", "bun"])
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "mix.exs")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "bun.install"
      assert content =~ "bun js"
    end

    test "configures bun css profile for tailwind" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.assets", ["--bundler", "bun"])
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "config/config.exs")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "run tailwindcss"
      refute content =~ "config :tailwind"
    end
  end

  describe "phx.install.assets --bundler bun --js-test" do
    test "adds bun test to the test alias" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.assets", ["--bundler", "bun", "--js-test"])
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "mix.exs")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "bun assets test"
    end

    test "does not add bun test by default" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.assets", ["--bundler", "bun"])
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "mix.exs")
      content = Rewrite.Source.get(source, :content)

      refute content =~ "bun assets test"
    end
  end

  describe "phx.install.assets --bundler bun --lang ts" do
    test "creates app.ts with TypeScript" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.assets", ["--bundler", "bun", "--lang", "ts"])
        |> apply_igniter!()

      assert Map.has_key?(igniter.rewrite.sources, "assets/js/app.ts")
      refute Map.has_key?(igniter.rewrite.sources, "assets/js/app.js")

      source = Rewrite.source!(igniter.rewrite, "assets/js/app.ts")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "LiveSocket"
      assert content =~ "declare global"
      assert content =~ ~s(import topbar from "topbar")
    end
  end
end
