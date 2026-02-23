defmodule Mix.Tasks.Phx.Install.CoreTest do
  use ExUnit.Case

  import Igniter.Test

  describe "phx.install.core" do
    test "adds phoenix dependency to mix.exs" do
      test_project()
      |> Igniter.compose_task("phx.install.core")
      |> assert_has_patch("mix.exs", """
      + | {:phoenix, "~> 1.7"}
      """)
    end

    test "creates application module" do
      test_project()
      |> Igniter.compose_task("phx.install.core")
      |> assert_creates("lib/test/application.ex")
    end

    test "application module has correct structure" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.core")
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "lib/test/application.ex")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "use Application"
      assert content =~ "def start(_type, _args)"
      assert content =~ "TestWeb.Telemetry"
      assert content =~ "Phoenix.PubSub"
      assert content =~ "TestWeb.Endpoint"
      assert content =~ "Test.Supervisor"
    end

    test "configures endpoint in config.exs" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.core")
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "config/config.exs")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "TestWeb.Endpoint"
      assert content =~ "Bandit.PhoenixAdapter"
      assert content =~ "TestWeb.ErrorJSON"
      assert content =~ "Test.PubSub"
      assert content =~ "live_view:"
    end

    test "configures phoenix json library" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.core")
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "config/config.exs")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "config :phoenix, json_library: Jason"
    end

    test "configures logger formatter" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.core")
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "config/config.exs")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "config :logger"
      assert content =~ "default_formatter"
      assert content =~ "request_id"
    end

    test "creates dev.exs with development settings" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.core")
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "config/dev.exs")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "TestWeb.Endpoint"
      assert content =~ "http: [ip: {127, 0, 0, 1}, port: 4000]"
      assert content =~ "code_reloader: true"
      assert content =~ "debug_errors: true"
      assert content =~ "secret_key_base:"
      assert content =~ "dev_routes: true"
    end

    test "creates test.exs with test settings" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.core")
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "config/test.exs")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "TestWeb.Endpoint"
      assert content =~ "port: 4002"
      assert content =~ "server: false"
      assert content =~ "config :logger, level: :warning"
    end

    test "creates prod.exs with production settings" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.core")
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "config/prod.exs")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "force_ssl:"
      assert content =~ "config :logger, level: :info"
    end

    test "creates runtime.exs" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.core")
        |> apply_igniter!()

      source = Rewrite.source!(igniter.rewrite, "config/runtime.exs")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "PHX_SERVER"
      assert content =~ "SECRET_KEY_BASE"
      assert content =~ "PHX_HOST"
      assert content =~ "dns_cluster_query"
    end

    test "imports phoenix in formatter" do
      test_project()
      |> Igniter.compose_task("phx.install.core")
      |> assert_has_patch(".formatter.exs", """
      + | import_deps: [:phoenix]
      """)
    end

    test "works with custom app name" do
      igniter =
        test_project(app_name: :my_app)
        |> Igniter.compose_task("phx.install.core")
        |> apply_igniter!()

      assert igniter.rewrite.sources["lib/my_app/application.ex"]

      source = Rewrite.source!(igniter.rewrite, "lib/my_app/application.ex")
      content = Rewrite.Source.get(source, :content)

      assert content =~ "MyAppWeb.Endpoint"
      assert content =~ "MyApp.PubSub"
    end

    test "is idempotent when secrets are provided" do
      args = [
        "--signing-salt",
        "test_salt",
        "--secret-key-base-dev",
        "dev_secret_key_base_1234567890123456789012345678901234567890",
        "--secret-key-base-test",
        "test_secret_key_base_123456789012345678901234567890123456789"
      ]

      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.core", args)
        |> apply_igniter!()

      igniter
      |> Igniter.compose_task("phx.install.core", args)
      |> assert_unchanged()
    end

    test "uses provided secrets instead of generating random ones" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install.core", [
          "--signing-salt",
          "my_custom_salt",
          "--secret-key-base-dev",
          "my_dev_secret",
          "--secret-key-base-test",
          "my_test_secret"
        ])
        |> apply_igniter!()

      config_content =
        Rewrite.source!(igniter.rewrite, "config/config.exs")
        |> Rewrite.Source.get(:content)

      assert config_content =~ "my_custom_salt"

      dev_content =
        Rewrite.source!(igniter.rewrite, "config/dev.exs")
        |> Rewrite.Source.get(:content)

      assert dev_content =~ "my_dev_secret"

      test_content =
        Rewrite.source!(igniter.rewrite, "config/test.exs")
        |> Rewrite.Source.get(:content)

      assert test_content =~ "my_test_secret"
    end
  end
end
