defmodule Mix.Tasks.Phx.InstallTest do
  use ExUnit.Case

  import Igniter.Test

  describe "phx.install" do
    test "composes core, endpoint, and router tasks" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install", [
          "--no-live",
          "--no-assets",
          "--no-gettext",
          "--no-dashboard",
          "--no-ecto",
          "--no-mailer"
        ])
        |> apply_igniter!()

      # Core artifacts
      assert igniter.rewrite.sources["lib/test/application.ex"]
      assert igniter.rewrite.sources["config/config.exs"]
      assert igniter.rewrite.sources["config/dev.exs"]

      # Endpoint artifacts
      assert igniter.rewrite.sources["lib/test_web.ex"]
      assert igniter.rewrite.sources["lib/test_web/endpoint.ex"]
      assert igniter.rewrite.sources["lib/test_web/telemetry.ex"]

      # Router artifacts
      assert igniter.rewrite.sources["lib/test_web/router.ex"]
      assert igniter.rewrite.sources["lib/test_web/controllers/error_json.ex"]
    end

    test "includes all optional tasks by default" do
      info = Mix.Tasks.Phx.Install.info([], nil)

      assert info.defaults[:ecto] == true
      assert info.defaults[:mailer] == true
      assert info.defaults[:live] == true
      assert info.defaults[:assets] == true
      assert info.defaults[:gettext] == true
      assert info.defaults[:dashboard] == true

      assert "phx.install.ecto" in info.composes
      assert "phx.install.mailer" in info.composes
      assert "phx.install.live" in info.composes
      assert "phx.install.assets" in info.composes
      assert "phx.install.gettext" in info.composes
      assert "phx.install.dashboard" in info.composes
    end

    test "respects --no-live flag" do
      info = Mix.Tasks.Phx.Install.info([], nil)
      assert :live in Keyword.keys(info.schema)
    end

    test "respects --no-assets flag" do
      info = Mix.Tasks.Phx.Install.info([], nil)
      assert :assets in Keyword.keys(info.schema)
    end

    test "works with custom app name" do
      igniter =
        test_project(app_name: :my_app)
        |> Igniter.compose_task("phx.install", [
          "--no-live",
          "--no-assets",
          "--no-gettext",
          "--no-dashboard",
          "--no-ecto",
          "--no-mailer"
        ])
        |> apply_igniter!()

      assert igniter.rewrite.sources["lib/my_app/application.ex"]
      assert igniter.rewrite.sources["lib/my_app_web.ex"]
      assert igniter.rewrite.sources["lib/my_app_web/endpoint.ex"]
      assert igniter.rewrite.sources["lib/my_app_web/router.ex"]
    end

    test "includes ecto by default" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install", [
          "--no-live",
          "--no-assets",
          "--no-gettext",
          "--no-dashboard",
          "--no-mailer"
        ])
        |> apply_igniter!()

      assert igniter.rewrite.sources["lib/test/repo.ex"]
    end

    test "respects --no-ecto flag" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install", [
          "--no-live",
          "--no-assets",
          "--no-gettext",
          "--no-dashboard",
          "--no-ecto",
          "--no-mailer"
        ])
        |> apply_igniter!()

      refute igniter.rewrite.sources["lib/test/repo.ex"]
    end

    test "includes mailer by default" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install", [
          "--no-live",
          "--no-assets",
          "--no-gettext",
          "--no-dashboard",
          "--no-ecto"
        ])
        |> apply_igniter!()

      assert igniter.rewrite.sources["lib/test/mailer.ex"]
    end

    test "respects --no-mailer flag" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install", [
          "--no-live",
          "--no-assets",
          "--no-gettext",
          "--no-dashboard",
          "--no-ecto",
          "--no-mailer"
        ])
        |> apply_igniter!()

      refute igniter.rewrite.sources["lib/test/application/mailer.ex"]
    end
  end

  describe "phx.install --css and --ui options" do
    test "defaults to css: tailwind and ui: daisy" do
      info = Mix.Tasks.Phx.Install.info([], nil)

      assert info.defaults[:css] == "tailwind"
      assert info.defaults[:ui] == "daisy"
    end

    test "rejects --ui daisy with --css none" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install", [
          "--ui",
          "daisy",
          "--css",
          "none",
          "--no-live",
          "--no-assets",
          "--no-gettext",
          "--no-dashboard",
          "--no-ecto",
          "--no-mailer"
        ])

      assert igniter.issues != []
      assert Enum.any?(igniter.issues, &String.contains?(&1, "daisy requires --css tailwind"))
    end
  end

  describe "phx_install.install" do
    test "--remove-after-install removes :phx_install from deps" do
      igniter =
        test_project()
        |> Igniter.Project.Deps.add_dep({:phx_install, "~> 0.1"})
        |> Igniter.compose_task("phx_install.install", [
          "--remove-after-install",
          "--no-live",
          "--no-assets",
          "--no-gettext",
          "--no-dashboard",
          "--no-ecto",
          "--no-mailer"
        ])
        |> apply_igniter!()

      mix_exs = Rewrite.Source.get(igniter.rewrite.sources["mix.exs"], :content)
      refute mix_exs =~ "phx_install"
    end
  end
end
