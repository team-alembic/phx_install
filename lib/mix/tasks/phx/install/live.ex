defmodule Mix.Tasks.Phx.Install.Live do
  @shortdoc "Adds Phoenix LiveView support"
  @moduledoc """
  Adds Phoenix LiveView support to an existing Phoenix application.

  This task sets up:
  - Adds `phoenix_live_view` dependency
  - Adds LiveView socket to the endpoint
  - Adds LiveView signing salt configuration
  - Adds `live_view` and `live_component` macros to the web module
  - Adds `Phoenix.LiveView.Router` import to router macro
  - Adds `alias Phoenix.LiveView.JS` and `show/2`, `hide/2` helpers to CoreComponents

  ## Usage

      mix phx.install.live

  ## Options

  - `--live-signing-salt` - Salt for signing LiveView tokens (generated if not provided)

  This task is typically called by `mix phx.install` rather than directly.
  """
  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :phoenix,
      example: "mix phx.install.live",
      adds_deps: [{:phoenix_live_view, "~> 1.0"}],
      schema: [
        live_signing_salt: :string
      ],
      composes: ["phx.install.html"]
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    app_name = Igniter.Project.Application.app_name(igniter)
    web_module = Igniter.Libs.Phoenix.web_module(igniter)
    endpoint_module = Module.concat(web_module, Endpoint)

    opts = igniter.args.options
    live_signing_salt = opts[:live_signing_salt] || PhxInstall.random_string(8)

    igniter
    |> Igniter.Project.Deps.add_dep({:phoenix_live_view, "~> 1.0"})
    |> Igniter.compose_task("phx.install.html")
    |> add_live_view_config(app_name, endpoint_module, live_signing_salt)
    |> add_socket_to_endpoint(endpoint_module)
    |> add_live_macros_to_web_module(web_module)
    |> add_live_router_import(web_module)
    |> add_js_helpers_to_core_components(web_module)
    |> upgrade_to_live_flash(web_module)
  end

  defp add_live_view_config(igniter, app_name, endpoint_module, live_signing_salt) do
    Igniter.Project.Config.configure(
      igniter,
      "config.exs",
      app_name,
      [endpoint_module, :live_view],
      signing_salt: live_signing_salt
    )
  end

  defp add_socket_to_endpoint(igniter, endpoint_module) do
    socket_code = """
    socket "/live", Phoenix.LiveView.Socket,
      websocket: [connect_info: [session: @session_options]],
      longpoll: [connect_info: [session: @session_options]]
    """

    Igniter.Project.Module.find_and_update_module!(igniter, endpoint_module, fn zipper ->
      case Igniter.Code.Function.move_to_function_call_in_current_scope(
             zipper,
             :socket,
             [2, 3],
             &Igniter.Code.Function.argument_equals?(&1, 0, "/live")
           ) do
        {:ok, _} -> {:ok, zipper}
        :error -> insert_socket_after_session_options(zipper, socket_code)
      end
    end)
  end

  defp insert_socket_after_session_options(zipper, socket_code) do
    case Igniter.Code.Common.move_to(zipper, fn z ->
           match?({:@, _, [{:session_options, _, _}]}, Sourceror.Zipper.node(z))
         end) do
      {:ok, session_opts_zipper} ->
        {:ok, Igniter.Code.Common.add_code(session_opts_zipper, socket_code)}

      :error ->
        {:warning,
         Igniter.Util.Warning.formatted_warning(
           "Could not add LiveView socket to endpoint. Please add it manually after @session_options:",
           socket_code
         )}
    end
  end

  defp add_live_macros_to_web_module(igniter, web_module) do
    live_view_code = """
    def live_view do
      quote do
        use Phoenix.LiveView

        unquote(html_helpers())
      end
    end
    """

    live_component_code = """
    def live_component do
      quote do
        use Phoenix.LiveComponent

        unquote(html_helpers())
      end
    end
    """

    Igniter.Project.Module.find_and_update_module!(igniter, web_module, fn zipper ->
      zipper = maybe_add_function(zipper, :live_view, 0, live_view_code)
      {:ok, maybe_add_function(zipper, :live_component, 0, live_component_code)}
    end)
  end

  defp maybe_add_function(zipper, function_name, arity, code) do
    case Igniter.Code.Function.move_to_def(zipper, function_name, arity) do
      {:ok, _} -> zipper
      :error -> add_function_at_best_location(zipper, code)
    end
  end

  defp add_function_at_best_location(zipper, code) do
    with :error <- Igniter.Code.Function.move_to_def(zipper, :html, 0, target: :at),
         :error <- Igniter.Code.Function.move_to_def(zipper, :verified_routes, 0, target: :at) do
      Igniter.Code.Common.add_code(zipper, code)
    else
      {:ok, target_zipper} ->
        Igniter.Code.Common.add_code(target_zipper, code, placement: :before)
    end
  end

  defp add_live_router_import(igniter, web_module) do
    import_code = "import Phoenix.LiveView.Router"

    Igniter.Project.Module.find_and_update_module!(igniter, web_module, fn zipper ->
      with {:ok, router_zipper} <- Igniter.Code.Function.move_to_def(zipper, :router, 0),
           {:ok, quote_body_zipper} <- Igniter.Code.Common.move_to_do_block(router_zipper),
           :error <-
             Igniter.Code.Function.move_to_function_call_in_current_scope(
               quote_body_zipper,
               :import,
               [1, 2],
               &Igniter.Code.Function.argument_equals?(&1, 0, Phoenix.LiveView.Router)
             ) do
        {:ok, Igniter.Code.Common.add_code(quote_body_zipper, import_code)}
      else
        {:ok, _existing_import} ->
          {:ok, zipper}

        :error ->
          {:ok, zipper}
      end
    end)
  end

  defp add_js_helpers_to_core_components(igniter, web_module) do
    core_components_module = Module.concat(web_module, CoreComponents)

    js_helpers_code = """
    alias Phoenix.LiveView.JS

    def show(js \\\\ %JS{}, selector) do
      JS.show(js,
        to: selector,
        time: 300,
        transition:
          {"transition-all ease-out duration-300",
           "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
           "opacity-100 translate-y-0 sm:scale-100"}
      )
    end

    def hide(js \\\\ %JS{}, selector) do
      JS.hide(js,
        to: selector,
        time: 200,
        transition:
          {"transition-all ease-in duration-200", "opacity-100 translate-y-0 sm:scale-100",
           "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
      )
    end
    """

    Igniter.Project.Module.find_and_update_module!(
      igniter,
      core_components_module,
      fn zipper ->
        case Igniter.Code.Function.move_to_def(zipper, :show, 2) do
          {:ok, _} -> {:ok, zipper}
          :error -> {:ok, Igniter.Code.Common.add_code(zipper, js_helpers_code)}
        end
      end
    )
  end

  defp upgrade_to_live_flash(igniter, web_module) do
    router_module = Module.concat(web_module, Router)

    case Igniter.Project.Module.find_and_update_module(
           igniter,
           router_module,
           &replace_fetch_flash_with_live_flash/1
         ) do
      {:ok, igniter} -> igniter
      {:error, igniter} -> igniter
    end
  end

  defp replace_fetch_flash_with_live_flash(zipper) do
    case Igniter.Code.Function.move_to_function_call(
           zipper,
           :plug,
           [1, 2],
           &Igniter.Code.Function.argument_equals?(&1, 0, :fetch_flash)
         ) do
      {:ok, flash_zipper} ->
        {:ok,
         Sourceror.Zipper.replace(
           flash_zipper,
           Sourceror.parse_string!("plug :fetch_live_flash")
         )}

      :error ->
        {:ok, zipper}
    end
  end
end
