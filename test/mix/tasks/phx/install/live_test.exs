defmodule Mix.Tasks.Phx.Install.LiveTest do
  use ExUnit.Case

  import Igniter.Test

  describe "phx.install.live" do
    test "adds phoenix_live_view dependency" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint")
        |> Igniter.compose_task("phx.install.live", ["--live-signing-salt", "testsalt1"])
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "mix.exs")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "phoenix_live_view"
    end

    test "adds live_view config to endpoint" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.core", [
          "--signing-salt",
          "testsalt1",
          "--secret-key-base-dev",
          "dev_secret_key_base_12345678901234567890123456789012",
          "--secret-key-base-test",
          "test_secret_key_base_12345678901234567890123456789012"
        ])
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.live", ["--live-signing-salt", "livesalt1"])
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "config/config.exs")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "live_view"
      assert content =~ "signing_salt"
    end

    test "adds socket to endpoint" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.live", ["--live-signing-salt", "livesalt1"])
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "lib/test_web/endpoint.ex")
      content = Rewrite.Source.get(source, :content)

      assert content =~ ~s|socket("/live", Phoenix.LiveView.Socket|
      assert content =~ "websocket:"
      assert content =~ "@session_options"
    end

    test "adds live_view macro to web module" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.live", ["--live-signing-salt", "livesalt1"])
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "lib/test_web.ex")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "def live_view do"
      assert content =~ "use Phoenix.LiveView"
    end

    test "adds live_component macro to web module" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.live", ["--live-signing-salt", "livesalt1"])
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "lib/test_web.ex")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "def live_component do"
      assert content =~ "use Phoenix.LiveComponent"
    end

    test "adds LiveView.Router import to router macro" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.live", ["--live-signing-salt", "livesalt1"])
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "lib/test_web.ex")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "import Phoenix.LiveView.Router"
    end

    test "adds show/2 and hide/2 JS helpers to CoreComponents" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.live", ["--live-signing-salt", "livesalt1"])
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "lib/test_web/components/core_components.ex")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "def show("
      assert content =~ "def hide("
      assert content =~ "alias Phoenix.LiveView.JS"
      assert content =~ "JS.show"
      assert content =~ "JS.hide"
    end

    test "is idempotent" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.live", ["--live-signing-salt", "livesalt1"])
        |> apply_igniter!()

      igniter
      |> Igniter.compose_task("phx.install.live", ["--live-signing-salt", "livesalt1"])
      |> assert_unchanged()
    end

    test "works with custom app name" do
      igniter =
        test_project(app_name: :my_app)
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.live", ["--live-signing-salt", "livesalt1"])
        |> apply_igniter!()

      assert igniter.rewrite.sources["lib/my_app_web.ex"]

      source = Rewrite.source!(igniter.rewrite, "lib/my_app_web.ex")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "def live_view do"
    end
  end
end
