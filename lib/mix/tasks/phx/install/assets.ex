defmodule Mix.Tasks.Phx.Install.Assets do
  @shortdoc "Sets up the asset pipeline"
  @moduledoc """
  Sets up the asset build pipeline for a Phoenix application.

  This is an orchestrator that composes individual asset subtasks based on
  the chosen bundler and options.

  ## Usage

      mix phx.install.assets
      mix phx.install.assets --bundler esbuild --lang ts
      mix phx.install.assets --no-tailwind
      mix phx.install.assets --bundler none

  ## Options

  - `--bundler` - JavaScript bundler to use: "esbuild" (default) or "none" to skip
  - `--lang` - Language for the JS entry point: "js" (default) or "ts"
  - `--tailwind` / `--no-tailwind` - Include Tailwind CSS (default: true)

  ## What Gets Installed

  Always installed:
  - `phx.install.assets.static` - robots.txt and favicon
  - `phx.install.assets.live_reload` - live reload configuration for dev

  Based on `--bundler`:
  - `phx.install.assets.esbuild` - esbuild + vendored topbar

  Optional:
  - `phx.install.assets.tailwind` - Tailwind CSS (runner varies by bundler)

  ## Extensibility

  To add support for a new bundler, implement two tasks:
  - `phx.install.assets.<bundler_name>` - JS bundling setup
  - `phx.install.assets.tailwind.<bundler_name>` - Tailwind CSS runner for that bundler

  This task is typically called by `mix phx.install` rather than directly.
  """
  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def info(argv, _composing_task) do
    {parsed, _, _} =
      OptionParser.parse(argv,
        strict: [bundler: :string, lang: :string, tailwind: :boolean]
      )

    bundler = Keyword.get(parsed, :bundler, "esbuild")
    tailwind? = Keyword.get(parsed, :tailwind, true)

    bundler_tasks = if bundler == "none", do: [], else: ["phx.install.assets.#{bundler}"]
    tailwind_tasks = if tailwind?, do: ["phx.install.assets.tailwind"], else: []

    %Igniter.Mix.Task.Info{
      group: :phoenix,
      example: "mix phx.install.assets",
      schema: [bundler: :string, lang: :string, tailwind: :boolean],
      defaults: [bundler: "esbuild", lang: "js", tailwind: true],
      composes:
        [
          "phx.install.assets.static",
          "phx.install.assets.live_reload"
        ] ++ bundler_tasks ++ tailwind_tasks
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    app_name = Igniter.Project.Application.app_name(igniter)

    opts = igniter.args.options
    bundler = opts[:bundler] || "esbuild"
    lang = opts[:lang] || "js"
    tailwind? = opts[:tailwind] != false

    igniter
    |> Igniter.compose_task("phx.install.assets.static")
    |> Igniter.compose_task("phx.install.assets.live_reload")
    |> maybe_compose_bundler(bundler, lang, tailwind?)
    |> maybe_compose_tailwind(tailwind?, bundler)
    |> maybe_add_aliases(app_name, bundler, tailwind?)
    |> update_setup_alias()
  end

  defp maybe_compose_bundler(igniter, "none", _lang, _tailwind?), do: igniter

  defp maybe_compose_bundler(igniter, bundler, lang, tailwind?) do
    Igniter.compose_task(
      igniter,
      "phx.install.assets.#{bundler}",
      bundler_args(lang, tailwind?)
    )
  end

  defp bundler_args(lang, tailwind?) do
    ["--lang", lang] ++
      if(tailwind?, do: [], else: ["--no-tailwind"])
  end

  defp maybe_compose_tailwind(igniter, false, _bundler), do: igniter

  defp maybe_compose_tailwind(igniter, _tailwind?, "none") do
    Igniter.compose_task(igniter, "phx.install.assets.tailwind", ["--bundler", "esbuild"])
  end

  defp maybe_compose_tailwind(igniter, _tailwind?, bundler) do
    Igniter.compose_task(igniter, "phx.install.assets.tailwind", ["--bundler", bundler])
  end

  defp maybe_add_aliases(igniter, _app_name, "none", _tailwind?), do: igniter

  defp maybe_add_aliases(igniter, app_name, "esbuild", tailwind?) do
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

  defp maybe_add_aliases(igniter, _app_name, _bundler, _tailwind?), do: igniter

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
