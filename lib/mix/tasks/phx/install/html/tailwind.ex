defmodule Mix.Tasks.Phx.Install.Html.Tailwind do
  @shortdoc "Adds Tailwind-only HTML components"
  @moduledoc """
  Adds plain Tailwind CSS core components, layouts, and templates.

  This task creates:
  - CoreComponents module with flash, flash_group, simple_form, button, input
  - Layouts module with `embed_templates`
  - Root HTML layout (`root.html.heex`)
  - App layout (`app.html.heex`)

  ## Usage

      mix phx.install.html.tailwind

  This task is typically composed by `mix phx.install.html` rather than called directly.
  """
  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :phoenix,
      example: "mix phx.install.html.tailwind"
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    web_module = Igniter.Libs.Phoenix.web_module(igniter)

    igniter
    |> create_core_components(web_module)
    |> create_layouts_module(web_module)
    |> create_root_layout(web_module)
    |> create_app_layout(web_module)
  end

  defp create_core_components(igniter, web_module) do
    core_components_module = Module.concat(web_module, CoreComponents)

    Igniter.Project.Module.find_and_update_or_create_module(
      igniter,
      core_components_module,
      """
      @moduledoc \"\"\"
      Provides core UI components.

      The components in this module use Tailwind CSS utility classes directly.
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
end
