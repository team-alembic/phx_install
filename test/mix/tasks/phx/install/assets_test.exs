defmodule Mix.Tasks.Phx.Install.AssetsTest do
  use ExUnit.Case

  import Igniter.Test

  describe "phx.install.assets" do
    test "declares esbuild and tailwind dependencies" do
      info = Mix.Tasks.Phx.Install.Assets.info([], nil)

      assert Enum.any?(info.adds_deps, fn dep -> elem(dep, 0) == :esbuild end)
      assert Enum.any?(info.adds_deps, fn dep -> elem(dep, 0) == :tailwind end)
    end

    test "creates assets/js/app.js" do
      test_project()
      |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
      |> Igniter.compose_task("phx.install.assets")
      |> assert_creates("assets/js/app.js")
    end

    test "app.js includes LiveSocket setup" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.assets")
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "assets/js/app.js")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "LiveSocket"
      assert content =~ "phoenix_live_view"
      assert content =~ "liveSocket.connect()"
    end

    test "creates assets/css/app.css" do
      test_project()
      |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
      |> Igniter.compose_task("phx.install.assets")
      |> assert_creates("assets/css/app.css")
    end

    test "app.css includes Tailwind imports" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.assets")
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "assets/css/app.css")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "@import \"tailwindcss\""
      assert content =~ "phx-click-loading"
    end

    test "creates assets/vendor/topbar.js" do
      test_project()
      |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
      |> Igniter.compose_task("phx.install.assets")
      |> assert_creates("assets/vendor/topbar.js")
    end

    test "creates priv/static/robots.txt" do
      test_project()
      |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
      |> Igniter.compose_task("phx.install.assets")
      |> assert_creates("priv/static/robots.txt")
    end

    test "creates priv/static/favicon.ico" do
      test_project()
      |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
      |> Igniter.compose_task("phx.install.assets")
      |> assert_creates("priv/static/favicon.ico")
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
      assert content =~ "--bundle"
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

    test "respects --no-esbuild flag" do
      info = Mix.Tasks.Phx.Install.Assets.info(["--no-esbuild"], nil)

      refute Enum.any?(info.adds_deps, fn dep -> elem(dep, 0) == :esbuild end)
      assert Enum.any?(info.adds_deps, fn dep -> elem(dep, 0) == :tailwind end)

      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.assets", ["--no-esbuild"])
        |> apply_igniter!()

      refute Map.has_key?(igniter.rewrite.sources, "assets/js/app.js")
    end

    test "respects --no-tailwind flag" do
      info = Mix.Tasks.Phx.Install.Assets.info(["--no-tailwind"], nil)

      assert Enum.any?(info.adds_deps, fn dep -> elem(dep, 0) == :esbuild end)
      refute Enum.any?(info.adds_deps, fn dep -> elem(dep, 0) == :tailwind end)

      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.assets", ["--no-tailwind"])
        |> apply_igniter!()

      refute Map.has_key?(igniter.rewrite.sources, "assets/css/app.css")
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
      # First run
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.assets")
        |> apply_igniter!()

      # Second run should succeed without errors
      # Note: strict byte-for-byte idempotency isn't guaranteed due to Sourceror
      # reformatting, but the task should not fail when run twice
      result =
        igniter
        |> Igniter.compose_task("phx.install.assets")

      assert result.issues == []
    end
  end
end
