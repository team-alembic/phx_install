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

  - `--ecto` / `--no-ecto` - Include Ecto database support (default: true)
  - `--mailer` / `--no-mailer` - Include Swoosh mailer (default: true)
  - `--live` / `--no-live` - Include LiveView support (default: true)
  - `--assets` / `--no-assets` - Include asset pipeline (default: true)
  - `--gettext` / `--no-gettext` - Include Gettext i18n (default: true)
  - `--dashboard` / `--no-dashboard` - Include LiveDashboard (default: true)
  - `--page` / `--no-page` - Include stock homepage (default: true)
  - `--all` - Enable all optional features, overriding any `--no-*` flags

  ## Examples

      # Install with all defaults
      mix igniter.install phx_install

      # API-only (no LiveView, no assets)
      mix igniter.install phx_install --no-live --no-assets

      # Skip database and mailer
      mix igniter.install phx_install --no-ecto --no-mailer
  """
  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :phx_install,
      example: "mix igniter.install phx_install",
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
      composes: ["phx.install"]
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    Igniter.compose_task(igniter, "phx.install")
  end
end
