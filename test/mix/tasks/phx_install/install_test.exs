defmodule Mix.Tasks.PhxInstall.InstallTest do
  use ExUnit.Case

  import Igniter.Test

  describe "phx_install.install" do
    test "composes phx.install task" do
      info = Mix.Tasks.PhxInstall.Install.info([], nil)

      assert "phx.install" in info.composes
    end

    test "passes through all options to phx.install" do
      info = Mix.Tasks.PhxInstall.Install.info([], nil)

      assert :live in Keyword.keys(info.schema)
      assert :assets in Keyword.keys(info.schema)
      assert :gettext in Keyword.keys(info.schema)
      assert :dashboard in Keyword.keys(info.schema)
    end

    test "defaults all options to true" do
      info = Mix.Tasks.PhxInstall.Install.info([], nil)

      assert info.defaults[:live] == true
      assert info.defaults[:assets] == true
      assert info.defaults[:gettext] == true
      assert info.defaults[:dashboard] == true
    end

    test "runs full installation" do
      igniter =
        test_project()
        |> Igniter.compose_task("phx_install.install", [
          "--no-live",
          "--no-assets",
          "--no-gettext",
          "--no-dashboard"
        ])
        |> apply_igniter!()

      # Core artifacts
      assert igniter.rewrite.sources["lib/test/application.ex"]
      assert igniter.rewrite.sources["config/config.exs"]

      # Endpoint artifacts
      assert igniter.rewrite.sources["lib/test_web.ex"]
      assert igniter.rewrite.sources["lib/test_web/endpoint.ex"]

      # Router artifacts
      assert igniter.rewrite.sources["lib/test_web/router.ex"]
    end
  end
end
