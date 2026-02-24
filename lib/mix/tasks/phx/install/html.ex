defmodule Mix.Tasks.Phx.Install.Html do
  @moduledoc """
  Adds HTML rendering support to a Phoenix application.

  This task sets up:
  - `phoenix_html` dependency
  - `lib/<app>_web/components/core_components.ex` - Core UI components
  - `lib/<app>_web/components/layouts.ex` - Layout component module
  - `lib/<app>_web/components/layouts/root.html.heex` - Root HTML layout
  - `lib/<app>_web/components/layouts/app.html.heex` - App layout
  - `lib/<app>_web/controllers/error_html.ex` - HTML error rendering
  - Updates web module with `html` and `html_helpers` functions

  ## Usage

      mix phx.install.html

  This task is typically called by `mix phx.install` rather than directly.
  """
  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :phoenix,
      example: "mix phx.install.html"
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    app_name = Igniter.Project.Application.app_name(igniter)
    web_module = Igniter.Libs.Phoenix.web_module(igniter)
    endpoint_module = Module.concat(web_module, Endpoint)

    igniter
    |> Igniter.Project.IgniterConfig.add_extension(Igniter.Extensions.Phoenix)
    |> Igniter.Project.Deps.add_dep({:phoenix_html, "~> 4.1"})
    |> create_core_components(web_module)
    |> create_layouts_module(web_module)
    |> create_root_layout(web_module)
    |> create_app_layout(web_module)
    |> create_error_html(web_module)
    |> add_html_helpers_to_web_module(web_module, endpoint_module)
    |> add_browser_pipeline_to_router(web_module)
    |> update_endpoint_error_config(app_name, endpoint_module, web_module)
  end

  defp create_core_components(igniter, web_module) do
    core_components_module = Module.concat(web_module, CoreComponents)

    Igniter.Project.Module.find_and_update_or_create_module(
      igniter,
      core_components_module,
      """
      @moduledoc \"\"\"
      Provides core UI components.

      The components in this module use function components and can be used
      in both regular views and LiveView.
      \"\"\"

      use Phoenix.Component

      @doc \"\"\"
      Renders flash notices.

      ## Examples

          <.flash kind={:info} flash={@flash} />
      \"\"\"
      attr :id, :string, doc: "the optional id of flash container"
      attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
      attr :title, :string, default: nil
      attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"
      attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

      slot :inner_block, doc: "the optional inner block that renders the flash message"

      def flash(assigns) do
        assigns = assign_new(assigns, :id, fn -> "flash-\#{assigns.kind}" end)

        ~H\"\"\"
        <div
          :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
          id={@id}
          role="alert"
          class={"flash flash-\#{@kind}"}
          {@rest}
        >
          <p :if={@title} class="flash-title">{@title}</p>
          <p class="flash-message">{msg}</p>
        </div>
        \"\"\"
      end

      @doc \"\"\"
      Shows the flash group with standard titles and content.

      ## Examples

          <.flash_group flash={@flash} />
      \"\"\"
      attr :flash, :map, required: true, doc: "the map of flash messages"
      attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

      def flash_group(assigns) do
        ~H\"\"\"
        <div id={@id}>
          <.flash kind={:info} flash={@flash} />
          <.flash kind={:error} flash={@flash} />
        </div>
        \"\"\"
      end

      @doc \"\"\"
      Renders a simple form.

      ## Examples

          <.simple_form for={@form} phx-change="validate" phx-submit="save">
            <.input field={@form[:email]} label="Email"/>
            <:actions>
              <.button>Save</.button>
            </:actions>
          </.simple_form>
      \"\"\"
      attr :for, :any, required: true, doc: "the data structure for the form"
      attr :as, :any, default: nil, doc: "the server side parameter to collect all input under"

      attr :rest, :global,
        include: ~w(autocomplete name rel action enctype method novalidate target multipart),
        doc: "the arbitrary HTML attributes to apply to the form tag"

      slot :inner_block, required: true
      slot :actions, doc: "the slot for form actions, such as a submit button"

      def simple_form(assigns) do
        ~H\"\"\"
        <.form :let={f} for={@for} as={@as} {@rest}>
          {render_slot(@inner_block, f)}
          <div :for={action <- @actions}>
            {render_slot(action, f)}
          </div>
        </.form>
        \"\"\"
      end

      @doc \"\"\"
      Renders a button with navigation support.

      ## Examples

          <.button>Send!</.button>
          <.button phx-click="go" variant="primary">Send!</.button>
          <.button navigate={~p"/"}>Home</.button>
      \"\"\"
      attr :rest, :global, include: ~w(href navigate patch method download name value disabled form)
      attr :class, :any
      attr :variant, :string, values: ~w(primary)
      slot :inner_block, required: true

      def button(%{rest: rest} = assigns) do
        variants = %{"primary" => "button-primary", nil => "button"}

        assigns =
          assign_new(assigns, :class, fn ->
            [Map.fetch!(variants, assigns[:variant])]
          end)

        if rest[:href] || rest[:navigate] || rest[:patch] do
          ~H\"\"\"
          <.link class={@class} {@rest}>
            {render_slot(@inner_block)}
          </.link>
          \"\"\"
        else
          ~H\"\"\"
          <button class={@class} {@rest}>
            {render_slot(@inner_block)}
          </button>
          \"\"\"
        end
      end

      @doc \"\"\"
      Renders an input with label and error messages.

      A `Phoenix.HTML.FormField` may be passed as argument,
      which is used to retrieve the input name, id, and values.
      Otherwise all attributes may be passed explicitly.

      ## Examples

          <.input field={@form[:email]} type="email" />
          <.input name="my-input" errors={["oh no!"]} />
      \"\"\"
      attr :id, :any, default: nil
      attr :name, :any
      attr :label, :string, default: nil
      attr :value, :any

      attr :type, :string,
        default: "text",
        values: ~w(checkbox color date datetime-local email file hidden month number password
                   range search select tel text textarea time url week)

      attr :field, Phoenix.HTML.FormField,
        doc: "a form field struct retrieved from the form, for example: @form[:email]"

      attr :errors, :list, default: []
      attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
      attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
      attr :options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"
      attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"

      attr :rest, :global,
        include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                    multiple pattern placeholder readonly required rows size step)

      def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
        errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

        assigns
        |> assign(field: nil, id: assigns.id || field.id)
        |> assign(:errors, Enum.map(errors, &translate_error(&1)))
        |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
        |> assign_new(:value, fn -> field.value end)
        |> input()
      end

      def input(%{type: "checkbox"} = assigns) do
        assigns =
          assign_new(assigns, :checked, fn ->
            Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
          end)

        ~H\"\"\"
        <div>
          <label>
            <input type="hidden" name={@name} value="false" disabled={@rest[:disabled]} />
            <input
              type="checkbox"
              id={@id}
              name={@name}
              value="true"
              checked={@checked}
              {@rest}
            />
            {@label}
          </label>
          <.error :for={msg <- @errors}>{msg}</.error>
        </div>
        \"\"\"
      end

      def input(%{type: "select"} = assigns) do
        ~H\"\"\"
        <div>
          <label :if={@label}>{@label}</label>
          <select id={@id} name={@name} multiple={@multiple} {@rest}>
            <option :if={@prompt} value="">{@prompt}</option>
            {Phoenix.HTML.Form.options_for_select(@options, @value)}
          </select>
          <.error :for={msg <- @errors}>{msg}</.error>
        </div>
        \"\"\"
      end

      def input(%{type: "textarea"} = assigns) do
        ~H\"\"\"
        <div>
          <label :if={@label}>{@label}</label>
          <textarea id={@id} name={@name} {@rest}>{Phoenix.HTML.Form.normalize_value("textarea", @value)}</textarea>
          <.error :for={msg <- @errors}>{msg}</.error>
        </div>
        \"\"\"
      end

      def input(%{type: "hidden"} = assigns) do
        ~H\"\"\"
        <input type="hidden" id={@id} name={@name} value={@value} {@rest} />
        \"\"\"
      end

      def input(assigns) do
        ~H\"\"\"
        <div>
          <label :if={@label}>{@label}</label>
          <input
            type={@type}
            name={@name}
            id={@id}
            value={Phoenix.HTML.Form.normalize_value(@type, @value)}
            {@rest}
          />
          <.error :for={msg <- @errors}>{msg}</.error>
        </div>
        \"\"\"
      end

      defp error(assigns) do
        ~H\"\"\"
        <p class="error">{render_slot(@inner_block)}</p>
        \"\"\"
      end

      @doc \"\"\"
      Translates an error message.
      \"\"\"
      def translate_error({msg, opts}) do
        Enum.reduce(opts, msg, fn {key, value}, acc ->
          String.replace(acc, "%{\#{key}}", fn _ -> to_string(value) end)
        end)
      end

      @doc \"\"\"
      Translates the errors for a field from a keyword list of errors.
      \"\"\"
      def translate_errors(errors, field) when is_list(errors) do
        for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
      end
      """,
      fn zipper -> {:ok, zipper} end
    )
  end

  defp create_layouts_module(igniter, web_module) do
    layouts_module = Module.concat(web_module, Layouts)

    Igniter.Project.Module.find_and_update_or_create_module(
      igniter,
      layouts_module,
      """
      @moduledoc \"\"\"
      This module holds different layouts used by your application.

      See the `layouts` directory for all templates available.
      \"\"\"
      use #{inspect(web_module)}, :html

      embed_templates "layouts/*"
      """,
      fn zipper -> {:ok, zipper} end
    )
  end

  defp create_root_layout(igniter, web_module) do
    app_module =
      web_module
      |> Module.split()
      |> List.first()
      |> then(fn name -> String.replace(name, "Web", "") end)

    layout_content = """
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta name="csrf-token" content={get_csrf_token()} />
        <.live_title default="#{app_module}">
          {assigns[:page_title]}
        </.live_title>
        <link phx-track-static rel="stylesheet" href={~p"/assets/css/app.css"} />
        <script defer phx-track-static type="text/javascript" src={~p"/assets/js/app.js"}>
        </script>
      </head>
      <body>
        {@inner_content}
      </body>
    </html>
    """

    web_module_snake =
      web_module
      |> Module.split()
      |> List.last()
      |> Macro.underscore()

    path = "lib/#{web_module_snake}/components/layouts/root.html.heex"

    Igniter.create_new_file(igniter, path, layout_content, on_exists: :skip)
  end

  defp create_app_layout(igniter, web_module) do
    layout_content = """
    <main class="container">
      <.flash_group flash={@flash} />
      {@inner_content}
    </main>
    """

    web_module_snake =
      web_module
      |> Module.split()
      |> List.last()
      |> Macro.underscore()

    path = "lib/#{web_module_snake}/components/layouts/app.html.heex"

    Igniter.create_new_file(igniter, path, layout_content, on_exists: :skip)
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

      # If you want to customize your error pages,
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
