defmodule Mix.Tasks.Phx.Install.MailerTest do
  use ExUnit.Case

  import Igniter.Test

  describe "phx.install.mailer" do
    test "declares swoosh dependency" do
      info = Mix.Tasks.Phx.Install.Mailer.info([], nil)
      assert {:swoosh, "~> 1.5"} in info.adds_deps
    end

    test "creates Mailer module" do
      test_project()
      |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
      |> Igniter.compose_task("phx.install.router")
      |> Igniter.compose_task("phx.install.mailer")
      |> assert_creates("lib/test/mailer.ex")
    end

    test "Mailer module uses Swoosh.Mailer" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.router")
        |> Igniter.compose_task("phx.install.mailer")
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "lib/test/mailer.ex")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "use Swoosh.Mailer"
      assert content =~ "otp_app: :test"
    end

    test "configures mailer in config.exs" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.router")
        |> Igniter.compose_task("phx.install.mailer")
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "config/config.exs")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "Test.Mailer"
      assert content =~ "Swoosh.Adapters.Local"
    end

    test "configures test mailer" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.router")
        |> Igniter.compose_task("phx.install.mailer")
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "config/test.exs")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "Test.Mailer"
      assert content =~ "Swoosh.Adapters.Test"
      assert content =~ "config :swoosh"
      assert content =~ "api_client"
    end

    test "configures dev swoosh" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.router")
        |> Igniter.compose_task("phx.install.mailer")
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "config/dev.exs")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "config :swoosh"
      assert content =~ "api_client"
    end

    test "configures prod swoosh" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.router")
        |> Igniter.compose_task("phx.install.mailer")
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "config/prod.exs")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "config :swoosh"
      assert content =~ "Swoosh.ApiClient.Req"
    end

    test "adds mailbox route to router" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.router")
        |> Igniter.compose_task("phx.install.mailer")
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "lib/test_web/router.ex")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "forward"
      assert content =~ "/mailbox"
      assert content =~ "Plug.Swoosh.MailboxPreview"
    end

    test "adds mailbox to existing dev_routes block" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.router")
        |> Igniter.compose_task("phx.install.dashboard")
        |> Igniter.compose_task("phx.install.mailer")
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "lib/test_web/router.ex")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "live_dashboard"
      assert content =~ "Plug.Swoosh.MailboxPreview"
      assert content =~ "dev_routes"
    end

    test "works with custom app name" do
      igniter =
        test_project(app_name: :my_app)
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.router")
        |> Igniter.compose_task("phx.install.mailer")
        |> apply_igniter!()

      assert igniter.rewrite.sources["lib/my_app/mailer.ex"]

      source = Rewrite.source!(igniter.rewrite, "lib/my_app/mailer.ex")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "defmodule MyApp.Mailer"
      assert content =~ "otp_app: :my_app"

      source = Rewrite.source!(igniter.rewrite, "config/config.exs")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "MyApp.Mailer"
    end

    test "running twice does not produce errors" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.endpoint", ["--session-signing-salt", "sessionsalt"])
        |> Igniter.compose_task("phx.install.router")
        |> Igniter.compose_task("phx.install.mailer")
        |> apply_igniter!()

      result =
        igniter
        |> Igniter.compose_task("phx.install.mailer")

      assert result.issues == []
    end
  end
end
