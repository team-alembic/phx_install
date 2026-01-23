defmodule Mix.Tasks.PhxInstall.Install do
  @moduledoc """
  Entry point for `mix igniter.install phx_install`.

  Installs Phoenix into an existing Elixir project by composing the
  `phx.install` task. This is the recommended way to add Phoenix to
  a project that was created with `mix new` or `mix igniter.new`.

  ## Usage

      mix igniter.install phx_install [options]

  ## Options

  All options are passed through to `phx.install`:

  - `--live` / `--no-live` - Include LiveView support (default: true)
  - `--assets` / `--no-assets` - Include asset pipeline (default: true)
  - `--gettext` / `--no-gettext` - Include Gettext i18n (default: true)
  - `--dashboard` / `--no-dashboard` - Include LiveDashboard (default: true)

  ## Examples

      # Install with all defaults
      mix igniter.install phx_install

      # API-only (no LiveView, no assets)
      mix igniter.install phx_install --no-live --no-assets
  """
  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :phx_install,
      example: "mix igniter.install phx_install",
      schema: [
        live: :boolean,
        assets: :boolean,
        gettext: :boolean,
        dashboard: :boolean
      ],
      defaults: [
        live: true,
        assets: true,
        gettext: true,
        dashboard: true
      ],
      composes: ["phx.install"]
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    Igniter.compose_task(igniter, "phx.install")
  end
end
