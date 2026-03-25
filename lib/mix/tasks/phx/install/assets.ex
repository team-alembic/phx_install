defmodule Mix.Tasks.Phx.Install.Assets do
  @shortdoc "Sets up the asset pipeline"
  @moduledoc """
  Sets up the asset build pipeline for a Phoenix application.

  This is an orchestrator that composes individual asset subtasks based on
  the chosen bundler and options.

  ## Usage

      mix phx.install.assets
      mix phx.install.assets --bundler bun --lang ts
      mix phx.install.assets --no-tailwind

  ## Options

  - `--bundler` - JavaScript bundler to use: "esbuild" (default) or "bun"
  - `--lang` - Language for the JS entry point: "js" (default) or "ts"
  - `--tailwind` / `--no-tailwind` - Include Tailwind CSS (default: true)
  - `--js-test` / `--no-js-test` - Add JS test runner to `mix test` alias (default: false, bun only)

  ## What Gets Installed

  Always installed:
  - `phx.install.assets.static` - robots.txt and favicon
  - `phx.install.assets.live_reload` - live reload configuration for dev

  Based on `--bundler`:
  - `phx.install.assets.esbuild` - esbuild + vendored topbar
  - `phx.install.assets.bun` - bun runtime + npm packages

  Optional:
  - `phx.install.assets.tailwind` - Tailwind CSS (runner varies by bundler)

  This task is typically called by `mix phx.install` rather than directly.
  """
  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def info(argv, _composing_task) do
    {parsed, _, _} =
      OptionParser.parse(argv,
        strict: [bundler: :string, lang: :string, tailwind: :boolean, js_test: :boolean]
      )

    bundler = Keyword.get(parsed, :bundler, "esbuild")
    tailwind? = Keyword.get(parsed, :tailwind, true)

    bundler_task = "phx.install.assets.#{bundler}"
    tailwind_tasks = if tailwind?, do: ["phx.install.assets.tailwind"], else: []

    %Igniter.Mix.Task.Info{
      group: :phoenix,
      example: "mix phx.install.assets",
      schema: [bundler: :string, lang: :string, tailwind: :boolean, js_test: :boolean],
      defaults: [bundler: "esbuild", lang: "js", tailwind: true, js_test: false],
      composes:
        [
          "phx.install.assets.static",
          "phx.install.assets.live_reload",
          bundler_task
        ] ++ tailwind_tasks
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    app_name = Igniter.Project.Application.app_name(igniter)

    opts = igniter.args.options
    bundler = opts[:bundler] || "esbuild"
    lang = opts[:lang] || "js"
    tailwind? = opts[:tailwind] != false
    js_test? = opts[:js_test] == true

    igniter
    |> Igniter.compose_task("phx.install.assets.static")
    |> Igniter.compose_task("phx.install.assets.live_reload")
    |> Igniter.compose_task(
      "phx.install.assets.#{bundler}",
      bundler_args(lang, tailwind?, js_test?)
    )
    |> maybe_compose_tailwind(tailwind?, bundler)
    |> add_aliases(app_name, bundler, tailwind?)
    |> update_setup_alias()
  end

  defp bundler_args(lang, tailwind?, js_test?) do
    ["--lang", lang] ++
      if(tailwind?, do: [], else: ["--no-tailwind"]) ++
      if(js_test?, do: ["--js-test"], else: [])
  end

  defp maybe_compose_tailwind(igniter, false, _bundler), do: igniter

  defp maybe_compose_tailwind(igniter, _tailwind?, bundler) do
    Igniter.compose_task(igniter, "phx.install.assets.tailwind", ["--bundler", bundler])
  end

  defp add_aliases(igniter, app_name, "esbuild", tailwind?) do
    setup_tasks =
      ["esbuild.install --if-missing"] ++
        if(tailwind?, do: ["tailwind.install --if-missing"], else: [])

    build_tasks =
      ["compile", "esbuild #{app_name}"] ++
        if(tailwind?, do: ["tailwind #{app_name}"], else: [])

    deploy_tasks =
      if(tailwind?, do: ["tailwind #{app_name} --minify"], else: []) ++
        ["esbuild #{app_name} --minify", "phx.digest"]

    igniter
    |> add_alias_if_missing("assets.setup", setup_tasks)
    |> add_alias_if_missing("assets.build", build_tasks)
    |> add_alias_if_missing("assets.deploy", deploy_tasks)
  end

  defp add_aliases(igniter, _app_name, "bun", tailwind?) do
    setup_tasks = ["bun.install --if-missing", "bun assets install"]

    build_tasks =
      ["compile", "bun js"] ++
        if(tailwind?, do: ["bun css"], else: [])

    deploy_tasks =
      if(tailwind?, do: ["bun css --minify"], else: []) ++
        ["bun js --minify", "phx.digest"]

    igniter
    |> add_alias_if_missing("assets.setup", setup_tasks)
    |> add_alias_if_missing("assets.build", build_tasks)
    |> add_alias_if_missing("assets.deploy", deploy_tasks)
  end

  defp add_alias_if_missing(igniter, alias_name, tasks) do
    Igniter.Project.TaskAliases.add_alias(igniter, alias_name, tasks, if_exists: :ignore)
  end

  defp update_setup_alias(igniter) do
    igniter
    |> Igniter.Project.TaskAliases.add_alias(
      "setup",
      ["deps.get", "assets.setup", "assets.build"],
      if_exists: {:append, "assets.setup"}
    )
    |> Igniter.Project.TaskAliases.add_alias(
      "setup",
      ["deps.get", "assets.setup", "assets.build"],
      if_exists: {:append, "assets.build"}
    )
  end
end
