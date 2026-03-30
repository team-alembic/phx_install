defmodule Mix.Tasks.Phx.Install.Assets do
  @shortdoc "Sets up the asset pipeline"
  @moduledoc """
  Sets up the asset build pipeline for a Phoenix application.

  This is an orchestrator that composes individual asset subtasks based on
  the chosen bundler and options.

  ## Usage

      mix phx.install.assets
      mix phx.install.assets --bundler esbuild --lang ts
      mix phx.install.assets --css none
      mix phx.install.assets --bundler none

  ## Options

  - `--bundler` - JavaScript bundler to use: "esbuild" (default) or "none" to skip
  - `--lang` - Language for the JS entry point: "js" (default) or "ts"
  - `--css` - CSS framework to use: "tailwind" (default) or "none" to skip

  ## What Gets Installed

  Always installed:
  - `phx.install.assets.static` - robots.txt and favicon
  - `phx.install.assets.live_reload` - live reload configuration for dev

  Based on `--bundler`:
  - `phx.install.assets.esbuild` - esbuild + vendored topbar

  Based on `--css`:
  - `phx.install.assets.css.tailwind` - Tailwind CSS (runner varies by bundler)

  ## Extensibility

  To add support for a new bundler, implement a task at
  `phx.install.assets.<bundler_name>`.

  To add support for a new CSS framework, implement a task at
  `phx.install.assets.css.<framework_name>`.

  This task is typically called by `mix phx.install` rather than directly.
  """
  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def info(argv, _composing_task) do
    {parsed, _, _} =
      OptionParser.parse(argv,
        strict: [bundler: :string, lang: :string, css: :string]
      )

    bundler = Keyword.get(parsed, :bundler, "esbuild")
    css = Keyword.get(parsed, :css, "tailwind")

    bundler_tasks = if bundler == "none", do: [], else: ["phx.install.assets.#{bundler}"]
    css_tasks = if css == "none", do: [], else: ["phx.install.assets.css"]

    %Igniter.Mix.Task.Info{
      group: :phoenix,
      example: "mix phx.install.assets",
      schema: [bundler: :string, lang: :string, css: :string],
      defaults: [bundler: "esbuild", lang: "js", css: "tailwind"],
      composes:
        [
          "phx.install.assets.static",
          "phx.install.assets.live_reload"
        ] ++ bundler_tasks ++ css_tasks
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    app_name = Igniter.Project.Application.app_name(igniter)

    opts = igniter.args.options
    bundler = opts[:bundler] || "esbuild"
    lang = opts[:lang] || "js"
    css = opts[:css] || "tailwind"

    igniter
    |> Igniter.compose_task("phx.install.assets.static")
    |> Igniter.compose_task("phx.install.assets.live_reload")
    |> maybe_compose_bundler(bundler, lang)
    |> maybe_create_app_css(css)
    |> maybe_compose_css(css, bundler)
    |> maybe_add_aliases(app_name, bundler, css)
    |> update_setup_alias()
  end

  defp maybe_compose_bundler(igniter, "none", _lang), do: igniter

  defp maybe_compose_bundler(igniter, bundler, lang) do
    Igniter.compose_task(igniter, "phx.install.assets.#{bundler}", ["--lang", lang])
  end

  defp maybe_create_app_css(igniter, "none"), do: igniter

  defp maybe_create_app_css(igniter, _css) do
    content = "/* This file is for your main application CSS */\n"
    Igniter.create_new_file(igniter, "assets/css/app.css", content, on_exists: :skip)
  end

  defp maybe_compose_css(igniter, "none", _bundler), do: igniter

  defp maybe_compose_css(igniter, css, "none") do
    Igniter.compose_task(igniter, "phx.install.assets.css", [
      "--css",
      css,
      "--bundler",
      "esbuild"
    ])
  end

  defp maybe_compose_css(igniter, css, bundler) do
    Igniter.compose_task(igniter, "phx.install.assets.css", [
      "--css",
      css,
      "--bundler",
      bundler
    ])
  end

  defp maybe_add_aliases(igniter, _app_name, "none", _css), do: igniter

  defp maybe_add_aliases(igniter, app_name, "esbuild", css) do
    tailwind? = css == "tailwind"

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

  defp maybe_add_aliases(igniter, _app_name, _bundler, _css), do: igniter

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
