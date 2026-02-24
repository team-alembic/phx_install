defmodule Mix.Tasks.Phx.Install do
  @moduledoc """
  Installs Phoenix into an Elixir project.

  This is the main orchestrator that composes individual installer tasks
  to set up a complete Phoenix application.

  ## Usage

      mix phx.install [options]

  ## Options

  - `--live` / `--no-live` - Include LiveView support (default: true)
  - `--assets` / `--no-assets` - Include asset pipeline (default: true)
  - `--gettext` / `--no-gettext` - Include Gettext i18n (default: true)
  - `--dashboard` / `--no-dashboard` - Include LiveDashboard (default: true)
  - `--page` / `--no-page` - Include stock homepage (default: true)

  ## What Gets Installed

  Always installed:
  - `phx.install.core` - Application module, config files, deps
  - `phx.install.endpoint` - Phoenix.Endpoint, Telemetry, web module
  - `phx.install.router` - Router with pipelines, error handling

  Optional (based on flags):
  - `phx.install.live` - LiveView socket and macros
  - `phx.install.assets` - esbuild, tailwind configuration
  - `phx.install.gettext` - Internationalization
  - `phx.install.heroicons` - Heroicon rendering (requires assets)
  - `phx.install.components` - Data display components (requires live)
  - `phx.install.page` - Stock homepage with PageController
  - `phx.install.dashboard` - LiveDashboard in dev

  ## Examples

      # Install with all defaults
      mix phx.install

      # API-only (no LiveView, no assets)
      mix phx.install --no-live --no-assets

      # Skip dashboard
      mix phx.install --no-dashboard
  """
  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :phoenix,
      example: "mix phx.install --live --assets",
      schema: [
        live: :boolean,
        assets: :boolean,
        gettext: :boolean,
        dashboard: :boolean,
        page: :boolean
      ],
      defaults: [
        live: true,
        assets: true,
        gettext: true,
        dashboard: true,
        page: true
      ],
      composes: [
        "phx.install.core",
        "phx.install.endpoint",
        "phx.install.router",
        "phx.install.live",
        "phx.install.assets",
        "phx.install.gettext",
        "phx.install.heroicons",
        "phx.install.components",
        "phx.install.page",
        "phx.install.dashboard"
      ]
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    opts = igniter.args.options

    igniter
    |> Igniter.compose_task("phx.install.core")
    |> Igniter.compose_task("phx.install.endpoint")
    |> Igniter.compose_task("phx.install.router")
    |> maybe_compose("phx.install.live", opts[:live])
    |> maybe_compose("phx.install.gettext", opts[:gettext])
    |> maybe_compose("phx.install.assets", opts[:assets])
    |> maybe_compose("phx.install.heroicons", opts[:assets])
    |> maybe_compose("phx.install.components", opts[:live])
    |> maybe_compose("phx.install.page", opts[:live] && opts[:page])
    |> maybe_compose("phx.install.dashboard", opts[:live] && opts[:dashboard])
  end

  defp maybe_compose(igniter, _task, false), do: igniter
  defp maybe_compose(igniter, task, _), do: Igniter.compose_task(igniter, task)
end
