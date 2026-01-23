defmodule Mix.Tasks.Phx.Install.Dashboard do
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
      example: "mix phx.install.dashboard"
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    app_name = Igniter.Project.Application.app_name(igniter)
    web_module = Igniter.Libs.Phoenix.web_module(igniter)
    router_module = Module.concat(web_module, Router)
    telemetry_module = Module.concat(web_module, Telemetry)

    igniter
    |> Igniter.Project.Deps.add_dep({:phoenix_live_dashboard, "~> 0.8"})
    |> add_dashboard_route(app_name, router_module, telemetry_module)
  end

  defp add_dashboard_route(igniter, app_name, router_module, telemetry_module) do
    dev_routes_code = """
    # Enable LiveDashboard in development
    if Application.compile_env(#{inspect(app_name)}, :dev_routes) do
      import Phoenix.LiveDashboard.Router

      scope "/dev" do
        pipe_through :browser

        live_dashboard "/dashboard", metrics: #{inspect(telemetry_module)}
      end
    end
    """

    Igniter.Project.Module.find_and_update_module!(igniter, router_module, fn zipper ->
      # Check if live_dashboard already exists
      case Igniter.Code.Function.move_to_function_call_in_current_scope(
             zipper,
             :live_dashboard,
             [1, 2],
             fn call ->
               Igniter.Code.Function.argument_equals?(call, 0, "/dashboard")
             end
           ) do
        {:ok, _} ->
          # Dashboard already exists
          {:ok, zipper}

        :error ->
          # Check if there's already a dev_routes block
          case Igniter.Code.Common.move_to(zipper, fn z ->
                 node = Sourceror.Zipper.node(z)

                 case node do
                   {:if, _, [{:compile_env, _, [_, ^app_name, :dev_routes | _]} | _]} -> true
                   {:if, _, [{:compile_env, _, [:erlang, :binary_to_atom, [^app_name | _], _]} | _]} -> true
                   _ -> false
                 end
               end) do
            {:ok, _dev_routes_zipper} ->
              # dev_routes block exists but no dashboard, this is complex to modify
              # Just skip and add a warning
              {:warning,
               Igniter.Util.Warning.formatted_warning(
                 "Found existing dev_routes block but couldn't add dashboard. Please add manually:",
                 dev_routes_code
               )}

            :error ->
              # No dev_routes block, add one at the end of the module
              {:ok, Igniter.Code.Common.add_code(zipper, dev_routes_code)}
          end
      end
    end)
  end
end
