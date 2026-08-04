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

    test "creates app.css with import lines" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.assets")
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "assets/css/app.css")
      content = Rewrite.Source.get(source, :content)

      assert content =~ ~s|@import "./phx-tailwind.css";|
    end

    test "creates phx-tailwind.css with tailwind foundation" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.assets")
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "assets/css/phx-tailwind.css")
      content = Rewrite.Source.get(source, :content)

      assert content =~ ~s|@import "tailwindcss" source(none);|
      assert content =~ ~s|@custom-variant phx-click-loading|
      assert content =~ ~s|data-phx-session|
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

      source = Rewrite.source!(igniter.rewrite, "assets/css/phx-tailwind.css")
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

  describe "phx.install.assets --css none" do
    test "skips tailwind configuration" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.assets", ["--css", "none"])
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "config/config.exs")
      content = Rewrite.Source.get(source, :content)

      refute content =~ "config :tailwind"
      refute Map.has_key?(igniter.rewrite.sources, "assets/css/app.css")
    end

    test "still creates JS assets" do
      test_project()
      |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
      |> Igniter.compose_task("phx.install.assets", ["--css", "none"])
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

  describe "phx.install.assets --bundler none" do
    test "skips JS bundling entirely" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.assets", ["--bundler", "none"])
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "config/config.exs")
      content = Rewrite.Source.get(source, :content)

      refute content =~ "config :esbuild"
      refute Map.has_key?(igniter.rewrite.sources, "assets/js/app.js")
      refute Map.has_key?(igniter.rewrite.sources, "assets/vendor/topbar.js")
    end

    test "still creates static files and live_reload" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.assets", ["--bundler", "none"])
        |> apply_igniter!()

      assert Map.has_key?(igniter.rewrite.sources, "priv/static/robots.txt")

      source = Rewrite.source!(igniter.rewrite, "config/dev.exs")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "live_reload:"
    end

    test "still creates tailwind CSS when not explicitly disabled" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.assets", ["--bundler", "none"])
        |> apply_igniter!()

      assert Map.has_key?(igniter.rewrite.sources, "assets/css/app.css")
      assert Map.has_key?(igniter.rewrite.sources, "assets/css/phx-tailwind.css")
    end
  end
end
