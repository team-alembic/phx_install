defmodule Mix.Tasks.Phx.Install.Components do
  @shortdoc "Adds data display components for Phoenix generators"
  @moduledoc """
  Adds data display components required by Phoenix generators.

  This is an orchestrator that delegates to a UI-variant-specific task
  based on the `--ui` flag.

  The following components are added to CoreComponents:
  - `header/1` — page header with title, subtitle, and actions
  - `table/1` — data table with streaming support
  - `list/1` — data list with title/content pairs

  These components are required by `phx.gen.html` and `phx.gen.live`.

  ## Usage

      mix phx.install.components
      mix phx.install.components --ui tailwind

  ## Options

  - `--ui` — UI component library: "daisy" (default) or "tailwind"

  ## Prerequisites

  This task requires LiveView to be installed (table/1 references
  `Phoenix.LiveView.LiveStream`). It is typically called by
  `mix phx.install` with the `--live` flag (default: true).

  This task is typically called by `mix phx.install` rather than directly.
  """
  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def info(argv, _composing_task) do
    {parsed, _, _} = OptionParser.parse(argv, strict: [ui: :string])
    ui = Keyword.get(parsed, :ui, "daisy")

    %Igniter.Mix.Task.Info{
      group: :phoenix,
      example: "mix phx.install.components",
      schema: [ui: :string],
      defaults: [ui: "daisy"],
      composes: ["phx.install.components.#{ui}"]
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    opts = igniter.args.options
    ui = opts[:ui] || "daisy"

    Igniter.compose_task(igniter, "phx.install.components.#{ui}")
  end
end
