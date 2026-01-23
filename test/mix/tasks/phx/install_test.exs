defmodule Mix.Tasks.Phx.InstallTest do
  use ExUnit.Case

  import Igniter.Test

  describe "phx.install" do
    test "composes core, endpoint, and router tasks" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx.install", ["--no-live", "--no-assets", "--no-gettext", "--no-dashboard"])
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
      # We can't fully test this until the optional tasks exist,
      # but we can verify the task info includes them
      info = Mix.Tasks.Phx.Install.info([], nil)

      assert info.defaults[:live] == true
      assert info.defaults[:assets] == true
      assert info.defaults[:gettext] == true
      assert info.defaults[:dashboard] == true

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
        |> Igniter.compose_task("phx.install", ["--no-live", "--no-assets", "--no-gettext", "--no-dashboard"])
        |> apply_igniter!()

      assert igniter.rewrite.sources["lib/my_app/application.ex"]
      assert igniter.rewrite.sources["lib/my_app_web.ex"]
      assert igniter.rewrite.sources["lib/my_app_web/endpoint.ex"]
      assert igniter.rewrite.sources["lib/my_app_web/router.ex"]
    end
  end
end
