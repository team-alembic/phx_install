defmodule Mix.Tasks.Phx.Install do
  @shortdoc "Installs Phoenix into an Elixir project"
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
  - `--css` - CSS framework: "tailwind" (default) or "none"
  - `--ui` - UI component library: "daisy" (default), "tailwind", or "none"

  ## What Gets Installed

  Always installed:
  - `phx.install.core` - Application module, config files, deps
  - `phx.install.endpoint` - Phoenix.Endpoint, Telemetry, web module
  - `phx.install.router` - Router with pipelines, error handling

  Optional (based on flags):
  - `phx.install.ecto` - Ecto database support, Repo, migrations
  - `phx.install.mailer` - Swoosh mailer and mailbox route
  - `phx.install.live` - LiveView socket and macros
  - `phx.install.assets` - esbuild, CSS framework configuration
  - `phx.install.gettext` - Internationalization
  - `phx.install.heroicons` - Heroicon rendering (requires assets)
  - `phx.install.html` - Core UI components (requires live)
  - `phx.install.components` - Data display components (requires live)
  - `phx.install.page` - Stock homepage with PageController
  - `phx.install.dashboard` - LiveDashboard in dev

  ## Examples

      # Install with all defaults (DaisyUI)
      mix phx.install

      # Plain Tailwind CSS (no DaisyUI)
      mix phx.install --ui tailwind

      # API-only (no LiveView, no assets)
      mix phx.install --no-live --no-assets

      # Skip database and mailer
      mix phx.install --no-ecto --no-mailer

  """
  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :phoenix,
      example: "mix phx.install --live --assets",
      schema: [
        assets: :boolean,
        css: :string,
        dashboard: :boolean,
        ecto: :boolean,
        gettext: :boolean,
        live: :boolean,
        mailer: :boolean,
        page: :boolean,
        ui: :string
      ],
      defaults: [
        assets: true,
        css: "tailwind",
        dashboard: true,
        ecto: true,
        gettext: true,
        live: true,
        mailer: true,
        page: true,
        ui: "daisy"
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
        "phx.install.html",
        "phx.install.components",
        "phx.install.page",
        "phx.install.dashboard"
      ]
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    opts = igniter.args.options
    ui = opts[:ui] || "daisy"
    css = opts[:css] || "tailwind"

    igniter
    |> validate_options(ui, css)
    |> Igniter.compose_task("phx.install.core")
    |> Igniter.compose_task("phx.install.endpoint")
    |> Igniter.compose_task("phx.install.router")
    |> maybe_compose("phx.install.ecto", opts[:ecto])
    |> maybe_compose("phx.install.mailer", opts[:mailer])
    |> maybe_compose("phx.install.live", opts[:live], ["--ui", ui])
    |> maybe_compose("phx.install.gettext", opts[:gettext])
    |> maybe_compose("phx.install.assets", opts[:assets], ["--css", css])
    |> maybe_compose("phx.install.heroicons", opts[:assets])
    |> maybe_compose("phx.install.components", opts[:live], ["--ui", ui])
    |> maybe_compose("phx.install.page", opts[:live] && opts[:page], ["--ui", ui])
    |> maybe_compose("phx.install.dashboard", opts[:live] && opts[:dashboard])
  end

  defp validate_options(igniter, ui, css) do
    if ui == "daisy" and css != "tailwind" do
      Igniter.add_issue(igniter, """
      Incompatible options: --ui daisy requires --css tailwind.

      DaisyUI is a Tailwind CSS plugin and cannot be used without Tailwind.
      Either use --css tailwind (default) or choose a different UI library with --ui tailwind.
      """)
    else
      igniter
    end
  end

  defp maybe_compose(igniter, _task, false, _args), do: igniter
  defp maybe_compose(igniter, task, _, args), do: Igniter.compose_task(igniter, task, args)

  defp maybe_compose(igniter, _task, false), do: igniter
  defp maybe_compose(igniter, task, _), do: Igniter.compose_task(igniter, task)
end
