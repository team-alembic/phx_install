defmodule PhxInstall.Acceptance.EquivalenceTest do
  @moduledoc """
  Acceptance tests that verify phx.new produces the expected output structure.

  These tests serve as a reference point to ensure our installers target
  the same file structure and dependencies as the official Phoenix generator.

  Run with: mix test test/acceptance --include acceptance
  """
  use ExUnit.Case, async: false

  @moduletag :acceptance
  @moduletag timeout: 60_000

  describe "phx.new reference output" do
    @tag :acceptance
    test "phx.new creates expected files and dependencies" do
      tmp_dir = create_tmp_dir()

      try do
        generate_phx_new_project(tmp_dir, "reference_app")
        project_dir = Path.join(tmp_dir, "reference_app")

        phx_new_files = list_project_files(project_dir)

        # Essential files that phx.new creates (and our installers should match)
        essential_files = [
          "mix.exs",
          "lib/reference_app/application.ex",
          "lib/reference_app_web.ex",
          "lib/reference_app_web/endpoint.ex",
          "lib/reference_app_web/router.ex",
          "lib/reference_app_web/telemetry.ex",
          "lib/reference_app_web/gettext.ex",
          "lib/reference_app/mailer.ex",
          "lib/reference_app/repo.ex",
          "config/config.exs",
          "config/dev.exs",
          "config/test.exs",
          "config/prod.exs",
          "config/runtime.exs",
          "test/test_helper.exs",
          "test/support/conn_case.ex",
          "test/support/data_case.ex",
          "priv/repo/seeds.exs",
          "priv/gettext/errors.pot",
          "assets/js/app.js",
          "assets/css/app.css"
        ]

        for file <- essential_files do
          assert file in phx_new_files,
                 "Expected #{file} in phx.new output.\nGot: #{inspect(phx_new_files)}"
        end

        # Essential dependencies that phx.new adds
        phx_new_deps = extract_deps_from_file(Path.join(project_dir, "mix.exs"))

        essential_deps = [
          :phoenix,
          :phoenix_html,
          :phoenix_live_view,
          :phoenix_live_dashboard,
          :ecto_sql,
          :postgrex,
          :swoosh,
          :gettext,
          :jason,
          :bandit,
          :esbuild,
          :tailwind
        ]

        for dep <- essential_deps do
          assert dep in phx_new_deps,
                 "Expected #{dep} in phx.new deps, got: #{inspect(phx_new_deps)}"
        end
      after
        File.rm_rf!(tmp_dir)
      end
    end

    @tag :acceptance
    test "phx.new project structure matches expected conventions" do
      tmp_dir = create_tmp_dir()

      try do
        generate_phx_new_project(tmp_dir, "structure_app")
        project_dir = Path.join(tmp_dir, "structure_app")

        # Verify config structure
        config_files = Path.wildcard(Path.join(project_dir, "config/*.exs"))
        config_names = Enum.map(config_files, &Path.basename/1) |> Enum.sort()
        assert config_names == ["config.exs", "dev.exs", "prod.exs", "runtime.exs", "test.exs"]

        # Verify lib structure
        assert File.dir?(Path.join(project_dir, "lib/structure_app"))
        assert File.dir?(Path.join(project_dir, "lib/structure_app_web"))
        assert File.dir?(Path.join(project_dir, "lib/structure_app_web/components"))
        assert File.dir?(Path.join(project_dir, "lib/structure_app_web/controllers"))

        # Verify priv structure
        assert File.dir?(Path.join(project_dir, "priv/repo/migrations"))
        assert File.dir?(Path.join(project_dir, "priv/gettext"))
        assert File.dir?(Path.join(project_dir, "priv/static"))

        # Verify assets structure
        assert File.dir?(Path.join(project_dir, "assets/js"))
        assert File.dir?(Path.join(project_dir, "assets/css"))

        # Verify test structure
        assert File.dir?(Path.join(project_dir, "test/support"))
      after
        File.rm_rf!(tmp_dir)
      end
    end
  end

  # Helper functions

  defp create_tmp_dir do
    tmp_base = System.tmp_dir!()
    unique_id = :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
    tmp_dir = Path.join(tmp_base, "phx_install_test_#{unique_id}")
    File.mkdir_p!(tmp_dir)
    tmp_dir
  end

  defp generate_phx_new_project(parent_dir, name) do
    original_dir = File.cwd!()

    try do
      File.cd!(parent_dir)
      Mix.Tasks.Phx.New.run([name, "--no-install"])
    after
      File.cd!(original_dir)
    end
  end

  defp list_project_files(project_dir) do
    project_dir
    |> Path.join("**/*")
    |> Path.wildcard()
    |> Enum.filter(&File.regular?/1)
    |> Enum.map(&Path.relative_to(&1, project_dir))
    |> Enum.reject(fn path ->
      String.starts_with?(path, "_build/") or
        String.starts_with?(path, "deps/") or
        String.starts_with?(path, ".git/") or
        path == "mix.lock"
    end)
    |> Enum.sort()
  end

  defp extract_deps_from_file(path) do
    content = File.read!(path)

    ~r/\{:(\w+),/
    |> Regex.scan(content)
    |> Enum.map(fn [_, dep] -> String.to_atom(dep) end)
    |> Enum.uniq()
  end
end
