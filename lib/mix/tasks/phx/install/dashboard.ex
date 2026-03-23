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
    dashboard_call =
      ~s|live_dashboard "/dashboard", metrics: #{inspect(telemetry_module)}|

    dev_routes_code = """
    if Application.compile_env(#{inspect(app_name)}, :dev_routes) do
      import Phoenix.LiveDashboard.Router

      scope "/dev" do
        pipe_through :browser

        #{dashboard_call}
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
        {:ok, _} ->
          {:ok, zipper}

        :error ->
          insert_dashboard_route(zipper, dashboard_call, dev_routes_code)
      end
    end)
  end

  defp insert_dashboard_route(zipper, dashboard_call, dev_routes_code) do
    case find_dev_routes_block(zipper) do
      {:ok, dev_routes_zipper} ->
        add_dashboard_to_existing_dev_scope(dev_routes_zipper, dashboard_call, dev_routes_code)

      :error ->
        {:ok, Igniter.Code.Common.add_code(zipper, dev_routes_code)}
    end
  end

  defp add_dashboard_to_existing_dev_scope(dev_routes_zipper, dashboard_call, dev_routes_code) do
    with {:ok, body_zipper} <- Igniter.Code.Common.move_to_do_block(dev_routes_zipper),
         {:ok, scope_zipper} <-
           Igniter.Code.Function.move_to_function_call_in_current_scope(
             body_zipper,
             :scope,
             [1, 2],
             &Igniter.Code.Function.argument_equals?(&1, 0, "/dev")
           ) do
      import_code = "import Phoenix.LiveDashboard.Router"
      with_import = Igniter.Code.Common.add_code(scope_zipper, import_code, placement: :before)

      fresh_zipper =
        with_import
        |> Sourceror.Zipper.root()
        |> Sourceror.Zipper.zip()

      with {:ok, dev_routes2} <- find_dev_routes_block(fresh_zipper),
           {:ok, body2} <- Igniter.Code.Common.move_to_do_block(dev_routes2),
           {:ok, scope2} <-
             Igniter.Code.Function.move_to_function_call_in_current_scope(
               body2,
               :scope,
               [1, 2],
               &Igniter.Code.Function.argument_equals?(&1, 0, "/dev")
             ),
           {:ok, scope_body2} <- Igniter.Code.Common.move_to_do_block(scope2) do
        {:ok, Igniter.Code.Common.add_code(scope_body2, dashboard_call)}
      else
        _ ->
          {:warning,
           Igniter.Util.Warning.formatted_warning(
             "Found existing dev_routes block but couldn't add dashboard route. Please add manually:",
             dev_routes_code
           )}
      end
    else
      _ ->
        {:warning,
         Igniter.Util.Warning.formatted_warning(
           "Found existing dev_routes block but couldn't add dashboard route. Please add manually:",
           dev_routes_code
         )}
    end
  end

  defp find_dev_routes_block(zipper) do
    Igniter.Code.Common.move_to(zipper, fn z ->
      case Sourceror.Zipper.node(z) do
        {:if, _,
         [
           {{:., _, [{:__aliases__, _, [:Application]}, :compile_env]}, _, args}
           | _
         ]} ->
          args_contain_dev_routes?(args)

        _ ->
          false
      end
    end)
  end

  defp args_contain_dev_routes?([_, {:__block__, _, [:dev_routes]} | _]), do: true
  defp args_contain_dev_routes?([_, :dev_routes | _]), do: true
  defp args_contain_dev_routes?(_), do: false
end
