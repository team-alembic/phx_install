defmodule Mix.Tasks.Phx.Install do
  @moduledoc """
  Installs Phoenix into an Elixir project.

  This is the main orchestrator that composes individual installer tasks
  to set up a complete Phoenix application.

  ## Usage

      mix phx.install [options]

  ## Options

  - `--ecto` / `--no-ecto` - Include Ecto database support (default: true)
  - `--mailer` / `--no-mailer` - Include Swoosh mailer (default: true)
  - `--live` / `--no-live` - Include LiveView support (default: true)
  - `--assets` / `--no-assets` - Include asset pipeline (default: true)
  - `--gettext` / `--no-gettext` - Include Gettext i18n (default: true)
  - `--dashboard` / `--no-dashboard` - Include LiveDashboard (default: true)
  - `--page` / `--no-page` - Include stock homepage (default: true)
  - `--all` - Enable all optional features, overriding any `--no-*` flags

  ## What Gets Installed

  Always installed:
  - `phx.install.core` - Application module, config files, deps
  - `phx.install.endpoint` - Phoenix.Endpoint, Telemetry, web module
  - `phx.install.router` - Router with pipelines, error handling

  Optional (based on flags):
  - `phx.install.ecto` - Ecto database support, Repo, migrations
  - `phx.install.mailer` - Swoosh mailer and mailbox route
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

      # Skip database and mailer
      mix phx.install --no-ecto --no-mailer

      # Enable everything (overrides any --no-* flags)
      mix phx.install --all
  """
  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :phoenix,
      example: "mix phx.install --live --assets",
      schema: [
        ecto: :boolean,
        mailer: :boolean,
        live: :boolean,
        assets: :boolean,
        gettext: :boolean,
        dashboard: :boolean,
        page: :boolean,
        all: :boolean
      ],
      defaults: [
        ecto: true,
        mailer: true,
        live: true,
        assets: true,
        gettext: true,
        dashboard: true,
        page: true,
        all: false
      ],
      composes: [
        "phx.install.core",
        "phx.install.endpoint",
        "phx.install.router",
        "phx.install.ecto",
        "phx.install.mailer",
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
    opts = resolve_opts(igniter.args.options)

    igniter
    |> Igniter.compose_task("phx.install.core")
    |> Igniter.compose_task("phx.install.endpoint")
    |> Igniter.compose_task("phx.install.router")
    |> maybe_compose("phx.install.ecto", opts[:ecto])
    |> maybe_compose("phx.install.mailer", opts[:mailer])
    |> maybe_compose("phx.install.live", opts[:live])
    |> maybe_compose("phx.install.gettext", opts[:gettext])
    |> maybe_compose("phx.install.assets", opts[:assets])
    |> maybe_compose("phx.install.heroicons", opts[:assets])
    |> maybe_compose("phx.install.components", opts[:live])
    |> maybe_compose("phx.install.page", opts[:live] && opts[:page])
    |> maybe_compose("phx.install.dashboard", opts[:live] && opts[:dashboard])
  end

  defp resolve_opts(opts) do
    if opts[:all] do
      Keyword.merge(opts,
        ecto: true,
        mailer: true,
        live: true,
        assets: true,
        gettext: true,
        dashboard: true,
        page: true
      )
    else
      opts
    end
  end

  defp maybe_compose(igniter, _task, false), do: igniter
  defp maybe_compose(igniter, task, _), do: Igniter.compose_task(igniter, task)
end
