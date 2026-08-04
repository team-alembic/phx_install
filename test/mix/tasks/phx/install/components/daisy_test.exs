defmodule Mix.Tasks.Phx.Install.Components.DaisyTest do
  use ExUnit.Case

  import Igniter.Test

  defp project_with_live do
    test_project()
    |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
    |> Igniter.compose_task("phx.install.live", [
      "--live-signing-salt",
      "livesalt1",
      "--ui",
      "daisy"
    ])
    |> apply_igniter!()
  end

  describe "phx.install.components --ui daisy" do
    test "adds header/1 to CoreComponents" do
      igniter =
        project_with_live()
        |> Igniter.compose_task("phx.install.components", ["--ui", "daisy"])
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "lib/test_web/components/core_components.ex")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "def header(assigns)"
      assert content =~ "slot(:subtitle)"
      assert content =~ "slot(:actions)"
    end

    test "adds table/1 with gettext to CoreComponents" do
      igniter =
        project_with_live()
        |> Igniter.compose_task("phx.install.components", ["--ui", "daisy"])
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "lib/test_web/components/core_components.ex")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "def table(assigns)"
      assert content =~ "Phoenix.LiveView.LiveStream"
      assert content =~ ~s|gettext("Actions")|
    end

    test "adds list/1 to CoreComponents" do
      igniter =
        project_with_live()
        |> Igniter.compose_task("phx.install.components", ["--ui", "daisy"])
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "lib/test_web/components/core_components.ex")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "def list(assigns)"
    end

    test "is idempotent" do
      igniter =
        project_with_live()
        |> Igniter.compose_task("phx.install.components", ["--ui", "daisy"])
        |> apply_igniter!()

      igniter
      |> Igniter.compose_task("phx.install.components", ["--ui", "daisy"])
      |> assert_unchanged()
    end
  end
end
