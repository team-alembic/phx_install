defmodule Mix.Tasks.Phx.Install.GettextTest do
  use ExUnit.Case

  import Igniter.Test

  describe "phx.install.gettext" do
    test "adds gettext dependency" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.gettext")
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "mix.exs")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "gettext"
    end

    test "creates Gettext backend module" do
      test_project()
      |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
      |> Igniter.compose_task("phx.install.gettext")
      |> assert_creates("lib/test_web/gettext.ex")
    end

    test "Gettext module uses Gettext.Backend" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.gettext")
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "lib/test_web/gettext.ex")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "use Gettext.Backend"
      assert content =~ "otp_app: :test"
    end

    test "creates errors.pot file" do
      test_project()
      |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
      |> Igniter.compose_task("phx.install.gettext")
      |> assert_creates("priv/gettext/errors.pot")
    end

    test "errors.pot contains template header" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.gettext")
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "priv/gettext/errors.pot")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "This is a PO Template file"
      assert content =~ "mix gettext.extract"
    end

    test "creates English errors.po file" do
      test_project()
      |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
      |> Igniter.compose_task("phx.install.gettext")
      |> assert_creates("priv/gettext/en/LC_MESSAGES/errors.po")
    end

    test "errors.po contains language header" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.gettext")
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "priv/gettext/en/LC_MESSAGES/errors.po")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "Language: en"
    end

    test "adds gettext to formatter" do
      # Note: we check before apply_igniter! because apply removes unchanged files
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.core")
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.gettext")

      source = Rewrite.source!(igniter.rewrite, ".formatter.exs")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "gettext"
    end

    test "works with custom app name" do
      igniter =
        test_project(app_name: :my_app)
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.gettext")
        |> apply_igniter!()

      assert igniter.rewrite.sources["lib/my_app_web/gettext.ex"]

      source = Rewrite.source!(igniter.rewrite, "lib/my_app_web/gettext.ex")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "defmodule MyAppWeb.Gettext"
      assert content =~ "otp_app: :my_app"
    end

    test "running twice does not produce errors" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.gettext")
        |> apply_igniter!()

      result =
        igniter
        |> Igniter.compose_task("phx.install.gettext")

      assert result.issues == []
    end
  end
end
