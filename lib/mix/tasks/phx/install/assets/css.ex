defmodule Mix.Tasks.Phx.Install.Assets.Css do
  @shortdoc "Sets up the CSS framework"
  @moduledoc """
  Sets up the CSS framework for a Phoenix application.

  This is an orchestrator that dynamically composes a CSS framework task
  based on the `--css` flag.

  ## Usage

      mix phx.install.assets.css
      mix phx.install.assets.css --css tailwind --bundler esbuild

  ## Options

  - `--css` - CSS framework to use: "tailwind" (default)
  - `--bundler` - Which bundler is in use: "esbuild" (default)

  ## Extensibility

  To add support for a new CSS framework, implement a task at
  `phx.install.assets.css.<framework_name>`.

  This task is typically composed by `mix phx.install.assets` rather than called directly.
  """
  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def info(argv, _composing_task) do
    {parsed, _, _} =
      OptionParser.parse(argv, strict: [css: :string, bundler: :string])

    css = Keyword.get(parsed, :css, "tailwind")

    %Igniter.Mix.Task.Info{
      group: :phoenix,
      example: "mix phx.install.assets.css",
      schema: [css: :string, bundler: :string],
      defaults: [css: "tailwind", bundler: "esbuild"],
      composes: ["phx.install.assets.css.#{css}"]
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    opts = igniter.args.options
    css = opts[:css] || "tailwind"
    bundler = opts[:bundler] || "esbuild"

    Igniter.compose_task(igniter, "phx.install.assets.css.#{css}", ["--bundler", bundler])
  end
end
