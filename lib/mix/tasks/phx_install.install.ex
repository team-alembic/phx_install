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
  - `--remove-after-install` / `--no-remove-after-install` - Remove `:phx_install` from deps after installation (default: false)

  ## Examples

      # Install with all defaults
      mix igniter.install phx_install

      # API-only (no LiveView, no assets)
      mix igniter.install phx_install --no-live --no-assets

      # Skip database and mailer
      mix igniter.install phx_install --no-ecto --no-mailer

      # Install and remove phx_install from deps
      mix igniter.install phx_install --remove-after-install
  """
  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :phx_install,
      example: "mix igniter.install phx_install",
      schema: [
        assets: :boolean,
        dashboard: :boolean,
        ecto: :boolean,
        gettext: :boolean,
        live: :boolean,
        mailer: :boolean,
        page: :boolean,
        remove_after_install: :boolean
      ],
      defaults: [
        assets: true,
        dashboard: true,
        ecto: true,
        gettext: true,
        live: true,
        mailer: true,
        page: true,
        remove_after_install: false
      ],
      composes: ["phx.install"]
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    opts = igniter.args.options

    igniter = Igniter.compose_task(igniter, "phx.install")

    if opts[:remove_after_install] do
      Igniter.Project.Deps.remove_dep(igniter, :phx_install)
    else
      igniter
    end
  end
end
