defmodule Mix.Tasks.Phx.Install.Assets.Tailwind.Bun do
  @shortdoc "Configures Tailwind CSS runner for Bun"
  @moduledoc """
  Configures Tailwind CSS to run via `@tailwindcss/cli` through Bun.

  This task sets up:
  - Bun `:css` profile in config.exs that runs `tailwindcss` via npm
  - Bun CSS watcher in dev.exs

  The `tailwindcss` and `@tailwindcss/cli` npm packages are expected to be
  in `assets/package.json` (handled by `phx.install.assets.bun`).

  ## Usage

      mix phx.install.assets.tailwind.bun

  This task is typically composed by `mix phx.install.assets.tailwind` rather than called directly.
  """
  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :phoenix,
      example: "mix phx.install.assets.tailwind.bun"
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    app_name = Igniter.Project.Application.app_name(igniter)
    web_module = Igniter.Libs.Phoenix.web_module(igniter)
    endpoint_module = Module.concat(web_module, Endpoint)

    igniter
    |> configure_css_profile()
    |> configure_watcher(app_name, endpoint_module)
  end

  defp configure_css_profile(igniter) do
    css_config =
      {:code,
       Sourceror.parse_string!("""
       [
         args: ~w(run tailwindcss --input=css/app.css --output=../priv/static/assets/css/app.css),
         cd: Path.expand("../assets", __DIR__)
       ]
       """)}

    Igniter.Project.Config.configure(
      igniter,
      "config.exs",
      :bun,
      [:css],
      css_config,
      updater: fn zipper -> {:ok, zipper} end
    )
  end

  defp configure_watcher(igniter, app_name, endpoint_module) do
    watcher_value =
      {:code, Sourceror.parse_string!("{Bun, :install_and_run, [:css, ~w(--watch)]}")}

    Igniter.Project.Config.configure(
      igniter,
      "dev.exs",
      app_name,
      [endpoint_module, :watchers, :bun_css],
      watcher_value,
      updater: fn zipper -> {:ok, zipper} end
    )
  end
end
