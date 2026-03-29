defmodule Mix.Tasks.Phx.Install.Assets.Tailwind.Esbuild do
  @shortdoc "Configures Tailwind CSS runner for esbuild"
  @moduledoc """
  Configures Tailwind CSS to run via the `tailwind` hex package (standalone CLI).

  This task sets up:
  - `tailwind` hex dependency
  - Tailwind version and profile configuration in config.exs
  - Tailwind watcher in dev.exs

  ## Usage

      mix phx.install.assets.tailwind.esbuild

  This task is typically composed by `mix phx.install.assets.tailwind` rather than called directly.
  """
  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :phoenix,
      example: "mix phx.install.assets.tailwind.esbuild",
      adds_deps: [{:tailwind, "~> 0.3"}]
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    app_name = Igniter.Project.Application.app_name(igniter)
    web_module = Igniter.Libs.Phoenix.web_module(igniter)
    endpoint_module = Module.concat(web_module, Endpoint)

    igniter
    |> Igniter.Project.Deps.add_dep({:tailwind, "~> 0.3"}, on_exists: :skip)
    |> set_runtime_dep()
    |> configure_tailwind(app_name)
    |> configure_watcher(app_name, endpoint_module)
  end

  defp set_runtime_dep(igniter) do
    Igniter.Project.Deps.set_dep_option(
      igniter,
      :tailwind,
      :runtime,
      Sourceror.parse_string!("Mix.env() == :dev")
    )
  end

  defp configure_tailwind(igniter, app_name) do
    app_config =
      {:code,
       Sourceror.parse_string!("""
       [
         args: ~w(
           --input=assets/css/app.css
           --output=priv/static/assets/css/app.css
         ),
         cd: Path.expand("..", __DIR__)
       ]
       """)}

    igniter
    |> Igniter.Project.Config.configure("config.exs", :tailwind, [:version], "4.1.12")
    |> Igniter.Project.Config.configure(
      "config.exs",
      :tailwind,
      [app_name],
      app_config,
      updater: fn zipper -> {:ok, zipper} end
    )
  end

  defp configure_watcher(igniter, app_name, endpoint_module) do
    watcher_value =
      {:code,
       Sourceror.parse_string!(
         "{Tailwind, :install_and_run, [#{inspect(app_name)}, ~w(--watch)]}"
       )}

    Igniter.Project.Config.configure(
      igniter,
      "dev.exs",
      app_name,
      [endpoint_module, :watchers, :tailwind],
      watcher_value,
      updater: fn zipper -> {:ok, zipper} end
    )
  end
end
