defmodule Mix.Tasks.Phx.Install.Dashboard do
  @shortdoc "Adds Phoenix LiveDashboard for development monitoring"
  @moduledoc """
  Adds Phoenix LiveDashboard for development monitoring.

  This task sets up:
  - `phoenix_live_dashboard` dependency
  - `/dev/dashboard` route in the router (only active in dev mode)
  - Imports `Phoenix.LiveDashboard.Router` in the router

  The dashboard is only accessible when `dev_routes` is true, which is
  typically only in the dev environment.

  ## Usage

      mix phx.install.dashboard

  ## Prerequisites

  This task requires LiveView to be installed. It is typically called by
  `mix phx.install` with the `--live` and `--dashboard` flags (both default to true).

  This task is typically called by `mix phx.install` rather than directly.
  """
  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :phoenix,
      example: "mix phx.install.dashboard",
      adds_deps: [{:phoenix_live_dashboard, "~> 0.8"}],
      composes: ["phx.install.endpoint", "phx.install.live"]
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    app_name = Igniter.Project.Application.app_name(igniter)
    web_module = Igniter.Libs.Phoenix.web_module(igniter)
    router_module = Module.concat(web_module, Router)
    telemetry_module = Module.concat(web_module, Telemetry)

    igniter
    |> Igniter.Project.Deps.add_dep({:phoenix, "~> 1.7"})
    |> Igniter.Project.Deps.add_dep({:phoenix_live_dashboard, "~> 0.8"})
    |> Igniter.compose_task("phx.install.endpoint")
    |> Igniter.compose_task("phx.install.live")
    |> add_dashboard_route(app_name, router_module, telemetry_module)
  end

  defp add_dashboard_route(igniter, app_name, router_module, telemetry_module) do
    dev_routes_code = """
    if Application.compile_env(#{inspect(app_name)}, :dev_routes) do
      import Phoenix.LiveDashboard.Router

      scope "/dev" do
        pipe_through :browser

        live_dashboard "/dashboard", metrics: #{inspect(telemetry_module)}
      end
    end
    """

    Igniter.Project.Module.find_and_update_module!(igniter, router_module, fn zipper ->
      case Igniter.Code.Function.move_to_function_call(
             zipper,
             :live_dashboard,
             [1, 2],
             &Igniter.Code.Function.argument_equals?(&1, 0, "/dashboard")
           ) do
        {:ok, _} -> {:ok, zipper}
        :error -> insert_dashboard_route(zipper, app_name, dev_routes_code)
      end
    end)
  end

  defp insert_dashboard_route(zipper, app_name, dev_routes_code) do
    case find_dev_routes_block(zipper, app_name) do
      {:ok, _} ->
        {:warning,
         Igniter.Util.Warning.formatted_warning(
           "Found existing dev_routes block but couldn't add dashboard. Please add manually:",
           dev_routes_code
         )}

      :error ->
        {:ok, Igniter.Code.Common.add_code(zipper, dev_routes_code)}
    end
  end

  defp find_dev_routes_block(zipper, app_name) do
    Igniter.Code.Common.move_to(zipper, fn z ->
      case Sourceror.Zipper.node(z) do
        {:if, _, [{:compile_env, _, [_, ^app_name, :dev_routes | _]} | _]} -> true
        {:if, _, [{:compile_env, _, [:erlang, :binary_to_atom, [^app_name | _], _]} | _]} -> true
        _ -> false
      end
    end)
  end
end
