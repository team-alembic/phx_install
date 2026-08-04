defmodule Mix.Tasks.Phx.Install.Html do
  @shortdoc "Adds HTML rendering support"
  @moduledoc """
  Adds HTML rendering support to a Phoenix application.

  This is an orchestrator that sets up shared HTML infrastructure
  and then delegates to a UI-variant-specific task for components,
  layouts, and templates.

  ## Shared infrastructure (always installed)

  - `phoenix_html` dependency
  - `lib/<app>_web/controllers/error_html.ex` — HTML error rendering
  - Web module `html/0` and `html_helpers/0` functions
  - Browser pipeline in router

  ## Variant-specific (based on `--ui`)

  - `phx.install.html.daisy` — DaisyUI components and layouts (default)
  - `phx.install.html.tailwind` — plain Tailwind CSS components and layouts

  ## Usage

      mix phx.install.html
      mix phx.install.html --ui tailwind

  ## Options

  - `--ui` — UI component library: "daisy" (default) or "tailwind"

  This task is typically called by `mix phx.install` rather than directly.
  """
  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def info(argv, _composing_task) do
    {parsed, _, _} = OptionParser.parse(argv, strict: [ui: :string])
    ui = Keyword.get(parsed, :ui, "daisy")

    %Igniter.Mix.Task.Info{
      group: :phoenix,
      example: "mix phx.install.html",
      adds_deps: [{:phoenix_html, "~> 4.1"}],
      schema: [ui: :string],
      defaults: [ui: "daisy"],
      composes: ["phx.install.html.#{ui}"]
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    app_name = Igniter.Project.Application.app_name(igniter)
    web_module = Igniter.Libs.Phoenix.web_module(igniter)
    endpoint_module = Module.concat(web_module, Endpoint)

    opts = igniter.args.options
    ui = opts[:ui] || "daisy"

    igniter
    |> Igniter.Project.Deps.add_dep({:phoenix, "~> 1.7"})
    |> Igniter.Project.Deps.add_dep({:phoenix_html, "~> 4.1"})
    |> Igniter.Project.IgniterConfig.add_extension(Igniter.Extensions.Phoenix)
    |> add_html_helpers_to_web_module(web_module, endpoint_module)
    |> add_browser_pipeline_to_router(web_module)
    |> update_endpoint_error_config(app_name, endpoint_module, web_module)
    |> create_error_html(web_module)
    |> Igniter.compose_task("phx.install.html.#{ui}")
  end

  defp create_error_html(igniter, web_module) do
    error_html_module = Module.concat(web_module, ErrorHTML)

    Igniter.Project.Module.find_and_update_or_create_module(
      igniter,
      error_html_module,
      """
      @moduledoc \"\"\"
      This module is invoked by your endpoint in case of errors on HTML requests.

      See config/config.exs.
      \"\"\"
      use #{inspect(web_module)}, :html

      # If you want to customise your error pages,
      # uncomment the embed_templates/1 call below
      # and add pages to the error directory:
      #
      #   * lib/#{Macro.underscore(web_module)}/controllers/error_html/404.html.heex
      #   * lib/#{Macro.underscore(web_module)}/controllers/error_html/500.html.heex
      #
      # embed_templates "error_html/*"

      # The default is to render a plain text page based on
      # the template name. For example, "404.html" becomes
      # "Not Found".
      def render(template, _assigns) do
        Phoenix.Controller.status_message_from_template(template)
      end
      """,
      fn zipper -> {:ok, zipper} end
    )
  end

  defp add_html_helpers_to_web_module(igniter, web_module, _endpoint_module) do
    html_code = """
    def html do
      quote do
        use Phoenix.Component

        import Phoenix.Controller,
          only: [get_csrf_token: 0, view_module: 1, view_template: 1]

        unquote(html_helpers())
      end
    end
    """

    html_helpers_code = """
    defp html_helpers do
      quote do
        import Phoenix.HTML

        import #{inspect(Module.concat(web_module, CoreComponents))}

        alias Phoenix.LiveView.JS

        alias #{inspect(Module.concat(web_module, Layouts))}

        unquote(verified_routes())
      end
    end
    """

    Igniter.Project.Module.find_and_update_module!(igniter, web_module, fn zipper ->
      zipper = maybe_add_function_before_verified_routes(zipper, :html, 0, html_code)
      zipper = maybe_add_private_function(zipper, :html_helpers, 0, html_helpers_code)
      {:ok, zipper}
    end)
  end

  defp maybe_add_function_before_verified_routes(zipper, function_name, arity, code) do
    case Igniter.Code.Function.move_to_def(zipper, function_name, arity) do
      {:ok, _} ->
        zipper

      :error ->
        case Igniter.Code.Function.move_to_def(zipper, :verified_routes, 0, target: :at) do
          {:ok, verified_routes_zipper} ->
            Igniter.Code.Common.add_code(verified_routes_zipper, code, placement: :before)

          :error ->
            Igniter.Code.Common.add_code(zipper, code)
        end
    end
  end

  defp maybe_add_private_function(zipper, function_name, arity, code) do
    case Igniter.Code.Function.move_to_defp(zipper, function_name, arity) do
      {:ok, _} ->
        zipper

      :error ->
        case Igniter.Code.Function.move_to_def(zipper, :verified_routes, 0, target: :at) do
          {:ok, verified_routes_zipper} ->
            Igniter.Code.Common.add_code(verified_routes_zipper, code, placement: :after)

          :error ->
            Igniter.Code.Common.add_code(zipper, code)
        end
    end
  end

  defp add_browser_pipeline_to_router(igniter, web_module) do
    router_module = Module.concat(web_module, Router)
    layouts_module = Module.concat(web_module, Layouts)

    browser_pipeline_code = """
    pipeline :browser do
      plug :accepts, ["html"]
      plug :fetch_session
      plug :fetch_flash
      plug :put_root_layout, html: {#{inspect(layouts_module)}, :root}
      plug :protect_from_forgery
      plug :put_secure_browser_headers
    end
    """

    case Igniter.Project.Module.find_and_update_module(
           igniter,
           router_module,
           &insert_browser_pipeline(&1, browser_pipeline_code)
         ) do
      {:ok, igniter} -> igniter
      {:error, igniter} -> igniter
    end
  end

  defp insert_browser_pipeline(zipper, browser_pipeline_code) do
    case Igniter.Code.Function.move_to_function_call_in_current_scope(
           zipper,
           :pipeline,
           2,
           &Igniter.Code.Function.argument_equals?(&1, 0, :browser)
         ) do
      {:ok, _} ->
        {:ok, zipper}

      :error ->
        insert_browser_pipeline_before_api(zipper, browser_pipeline_code)
    end
  end

  defp insert_browser_pipeline_before_api(zipper, browser_pipeline_code) do
    case Igniter.Code.Function.move_to_function_call_in_current_scope(
           zipper,
           :pipeline,
           2,
           &Igniter.Code.Function.argument_equals?(&1, 0, :api)
         ) do
      {:ok, api_zipper} ->
        {:ok, Igniter.Code.Common.add_code(api_zipper, browser_pipeline_code, placement: :before)}

      :error ->
        {:ok, Igniter.Code.Common.add_code(zipper, browser_pipeline_code)}
    end
  end

  defp update_endpoint_error_config(igniter, app_name, endpoint_module, web_module) do
    error_html_module = Module.concat(web_module, ErrorHTML)
    error_json_module = Module.concat(web_module, ErrorJSON)

    Igniter.Project.Config.configure(
      igniter,
      "config.exs",
      app_name,
      [endpoint_module, :render_errors, :formats],
      [html: error_html_module, json: error_json_module],
      updater: fn zipper ->
        {:ok, zipper}
      end
    )
  end
end
