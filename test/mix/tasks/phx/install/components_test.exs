defmodule Mix.Tasks.Phx.Install.ComponentsTest do
  use ExUnit.Case

  import Igniter.Test

  defp project_with_live do
    test_project()
    |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
    |> Igniter.compose_task("phx.install.live", ["--live-signing-salt", "livesalt1"])
    |> apply_igniter!()
  end

  describe "phx.install.components" do
    test "adds header/1 to CoreComponents" do
      igniter =
        project_with_live()
        |> Igniter.compose_task("phx.install.components")
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "lib/test_web/components/core_components.ex")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "def header(assigns)"
      assert content =~ "slot(:subtitle)"
      assert content =~ "slot(:actions)"
    end

    test "adds table/1 to CoreComponents" do
      igniter =
        project_with_live()
        |> Igniter.compose_task("phx.install.components")
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "lib/test_web/components/core_components.ex")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "def table(assigns)"
      assert content =~ "attr(:id, :string, required: true)"
      assert content =~ "attr(:rows, :list, required: true)"
      assert content =~ "Phoenix.LiveView.LiveStream"
    end

    test "adds list/1 to CoreComponents" do
      igniter =
        project_with_live()
        |> Igniter.compose_task("phx.install.components")
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "lib/test_web/components/core_components.ex")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "def list(assigns)"
      assert content =~ "attr(:title, :string, required: true)"
    end

    test "is idempotent" do
      igniter =
        project_with_live()
        |> Igniter.compose_task("phx.install.components")
        |> apply_igniter!()

      igniter
      |> Igniter.compose_task("phx.install.components")
      |> assert_unchanged()
    end

    test "works with custom app name" do
      igniter =
        test_project(app_name: :my_app)
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.live", ["--live-signing-salt", "livesalt1"])
        |> apply_igniter!()
        |> Igniter.compose_task("phx.install.components")
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "lib/my_app_web/components/core_components.ex")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "def header(assigns)"
      assert content =~ "def table(assigns)"
      assert content =~ "def list(assigns)"
    end
  end
end
