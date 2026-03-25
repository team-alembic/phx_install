defmodule Mix.Tasks.Phx.Install.Assets.LiveReload do
  @shortdoc "Configures live reload for development"
  @moduledoc """
  Configures Phoenix live reload for development.

  This task sets up the `live_reload` configuration in `dev.exs` which
  watches for file changes and triggers browser reloads during development.

  ## Usage

      mix phx.install.assets.live_reload

  This task is typically composed by `mix phx.install.assets` rather than called directly.
  """
  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :phoenix,
      example: "mix phx.install.assets.live_reload"
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    app_name = Igniter.Project.Application.app_name(igniter)
    web_module = Igniter.Libs.Phoenix.web_module(igniter)
    endpoint_module = Module.concat(web_module, Endpoint)

    live_reload_config =
      {:code,
       Sourceror.parse_string!("""
       [
         web_console_logger: true,
         patterns: [
           ~r"priv/static/(?!uploads/).*\\.(js|css|png|jpeg|jpg|gif|svg)$",
           ~r"lib/.*_web/router\\.ex$",
           ~r"lib/.*_web/(controllers|live|components)/.*\\.(ex|heex)$"
         ]
       ]
       """)}

    Igniter.Project.Config.configure(
      igniter,
      "dev.exs",
      app_name,
      [endpoint_module, :live_reload],
      live_reload_config,
      updater: fn zipper -> {:ok, zipper} end
    )
  end
end
