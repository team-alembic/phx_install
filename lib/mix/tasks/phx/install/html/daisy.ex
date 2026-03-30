defmodule Mix.Tasks.Phx.Install.Html.Daisy do
  @shortdoc "Adds DaisyUI HTML components"
  @moduledoc """
  Adds DaisyUI core components, layouts, and templates.

  This task creates:
  - CoreComponents module with DaisyUI-styled flash, button, input, simple_form
  - Layouts module with inline `app/1`, `flash_group/1`, and `theme_toggle/1`
  - Root HTML layout with theme-switching JavaScript
  - DaisyUI CSS configuration (`assets/css/phx-daisy.css`)
  - DaisyUI vendor JS files (`assets/vendor/daisyui.js`, `assets/vendor/daisyui-theme.js`)
  - Phoenix logo SVG (`priv/static/images/logo.svg`)

  ## Usage

      mix phx.install.html.daisy

  This task is typically composed by `mix phx.install.html` rather than called directly.
  """
  use Igniter.Mix.Task

  @daisyui_version "5.5.19"
  @daisyui_base_url "https://github.com/saadeghi/daisyui/releases/download/v#{@daisyui_version}"

  @impl Igniter.Mix.Task
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :phoenix,
      example: "mix phx.install.html.daisy"
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    web_module = Igniter.Libs.Phoenix.web_module(igniter)

    igniter
    |> create_core_components(web_module)
    |> create_layouts_module(web_module)
    |> create_root_layout(web_module)
    |> create_logo_svg()
    |> create_daisy_css()
    |> PhxInstall.append_css_import(~s|@import "./phx-daisy.css";|)
    |> download_vendor_file("daisyui.js")
    |> download_vendor_file("daisyui-theme.js")
  end

  defp create_core_components(igniter, web_module) do
    core_components_module = Module.concat(web_module, CoreComponents)
    gettext_module = Module.concat(web_module, Gettext)

    Igniter.Project.Module.find_and_update_or_create_module(
      igniter,
      core_components_module,
      core_components_code(gettext_module),
      fn zipper -> {:ok, zipper} end
    )
  end

  defp core_components_code(gettext_module) do
    """
    @moduledoc \"\"\"
    Provides core UI components.

    The foundation for styling is Tailwind CSS, a utility-first CSS framework,
    augmented with daisyUI, a Tailwind CSS plugin that provides UI components
    and themes. Here are useful references:

      * [daisyUI](https://daisyui.com/docs/intro/) - a good place to get
        started and see the available components.

      * [Tailwind CSS](https://tailwindcss.com) - the foundational framework
        we build on. You will use it for layout, sizing, flexbox, grid, and
        spacing.

      * [Heroicons](https://heroicons.com) - see `icon/1` for usage.

      * [Phoenix.Component](https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html) -
        the component system used by Phoenix. Some components, such as `<.link>`
        and `<.form>`, are defined there.

    \"\"\"
    use Phoenix.Component
    use Gettext, backend: #{inspect(gettext_module)}

    @doc \"\"\"
    Renders flash notices.

    ## Examples

        <.flash kind={:info} flash={@flash} />
        <.flash kind={:info} phx-mounted={show("#flash")}>Welcome Back!</.flash>
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
        phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("#\#{@id}")}
        role="alert"
        class="toast toast-top toast-end z-50"
        {@rest}
      >
        <div class={[
          "alert w-80 sm:w-96 max-w-80 sm:max-w-96 text-wrap",
          @kind == :info && "alert-info",
          @kind == :error && "alert-error"
        ]}>
          <.icon :if={@kind == :info} name="hero-information-circle" class="size-5 shrink-0" />
          <.icon :if={@kind == :error} name="hero-exclamation-circle" class="size-5 shrink-0" />
          <div>
            <p :if={@title} class="font-semibold">{@title}</p>
            <p>{msg}</p>
          </div>
          <div class="flex-1" />
          <button type="button" class="group self-start cursor-pointer" aria-label={gettext("close")}>
            <.icon name="hero-x-mark" class="size-5 opacity-40 group-hover:opacity-70" />
          </button>
        </div>
      </div>
      \"\"\"
    end

    @doc \"\"\"
    Renders a button with navigation support.

    ## Examples

        <.button>Send!</.button>
        <.button phx-click="go" variant="primary">Send!</.button>
        <.button navigate={~p"/"}>Home</.button>
    \"\"\"
    attr :rest, :global, include: ~w(href navigate patch method download name value disabled)
    attr :class, :any
    attr :variant, :string, values: ~w(primary)
    slot :inner_block, required: true

    def button(%{rest: rest} = assigns) do
      variants = %{"primary" => "btn-primary", nil => "btn-primary btn-soft"}

      assigns =
        assign_new(assigns, :class, fn ->
          ["btn", Map.fetch!(variants, assigns[:variant])]
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
      values: ~w(checkbox color date datetime-local email file month number password
                 search select tel text textarea time url week hidden)

    attr :field, Phoenix.HTML.FormField,
      doc: "a form field struct retrieved from the form, for example: @form[:email]"

    attr :errors, :list, default: []
    attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
    attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
    attr :options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"
    attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"
    attr :class, :any, default: nil, doc: "the input class to use over defaults"
    attr :error_class, :any, default: nil, doc: "the input error class to use over defaults"

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

    def input(%{type: "hidden"} = assigns) do
      ~H\"\"\"
      <input type="hidden" id={@id} name={@name} value={@value} {@rest} />
      \"\"\"
    end

    def input(%{type: "checkbox"} = assigns) do
      assigns =
        assign_new(assigns, :checked, fn ->
          Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
        end)

      ~H\"\"\"
      <div class="fieldset mb-2">
        <label for={@id}>
          <input
            type="hidden"
            name={@name}
            value="false"
            disabled={@rest[:disabled]}
            form={@rest[:form]}
          />
          <span class="label">
            <input
              type="checkbox"
              id={@id}
              name={@name}
              value="true"
              checked={@checked}
              class={@class || "checkbox checkbox-sm"}
              {@rest}
            />{@label}
          </span>
        </label>
        <.error :for={msg <- @errors}>{msg}</.error>
      </div>
      \"\"\"
    end

    def input(%{type: "select"} = assigns) do
      ~H\"\"\"
      <div class="fieldset mb-2">
        <label for={@id}>
          <span :if={@label} class="label mb-1">{@label}</span>
          <select
            id={@id}
            name={@name}
            class={[@class || "w-full select", @errors != [] && (@error_class || "select-error")]}
            multiple={@multiple}
            {@rest}
          >
            <option :if={@prompt} value="">{@prompt}</option>
            {Phoenix.HTML.Form.options_for_select(@options, @value)}
          </select>
        </label>
        <.error :for={msg <- @errors}>{msg}</.error>
      </div>
      \"\"\"
    end

    def input(%{type: "textarea"} = assigns) do
      ~H\"\"\"
      <div class="fieldset mb-2">
        <label for={@id}>
          <span :if={@label} class="label mb-1">{@label}</span>
          <textarea
            id={@id}
            name={@name}
            class={[
              @class || "w-full textarea",
              @errors != [] && (@error_class || "textarea-error")
            ]}
            {@rest}
          >{Phoenix.HTML.Form.normalize_value("textarea", @value)}</textarea>
        </label>
        <.error :for={msg <- @errors}>{msg}</.error>
      </div>
      \"\"\"
    end

    def input(assigns) do
      ~H\"\"\"
      <div class="fieldset mb-2">
        <label for={@id}>
          <span :if={@label} class="label mb-1">{@label}</span>
          <input
            type={@type}
            name={@name}
            id={@id}
            value={Phoenix.HTML.Form.normalize_value(@type, @value)}
            class={[
              @class || "w-full input",
              @errors != [] && (@error_class || "input-error")
            ]}
            {@rest}
          />
        </label>
        <.error :for={msg <- @errors}>{msg}</.error>
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

    defp error(assigns) do
      ~H\"\"\"
      <p class="mt-1.5 flex gap-2 items-center text-sm text-error">
        <.icon name="hero-exclamation-circle" class="size-5" />
        {render_slot(@inner_block)}
      </p>
      \"\"\"
    end

    @doc \"\"\"
    Translates an error message using gettext.
    \"\"\"
    def translate_error({msg, opts}) do
      if count = opts[:count] do
        Gettext.dngettext(#{inspect(gettext_module)}, "errors", msg, msg, count, opts)
      else
        Gettext.dgettext(#{inspect(gettext_module)}, "errors", msg, opts)
      end
    end

    @doc \"\"\"
    Translates the errors for a field from a keyword list of errors.
    \"\"\"
    def translate_errors(errors, field) when is_list(errors) do
      for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
    end
    """
  end

  defp create_layouts_module(igniter, web_module) do
    layouts_module = Module.concat(web_module, Layouts)

    Igniter.Project.Module.find_and_update_or_create_module(
      igniter,
      layouts_module,
      layouts_code(web_module),
      fn zipper -> {:ok, zipper} end
    )
  end

  defp layouts_code(web_module) do
    """
    @moduledoc \"\"\"
    This module holds layouts and related functionality
    used by your application.
    \"\"\"
    use #{inspect(web_module)}, :html

    embed_templates "layouts/*"

    @doc \"\"\"
    Renders your app layout.
    \"\"\"
    attr :flash, :map, required: true, doc: "the map of flash messages"

    attr :current_scope, :map,
      default: nil,
      doc: "the current scope"

    slot :inner_block, required: true

    def app(assigns) do
      ~H\"\"\"
      <header class="navbar px-4 sm:px-6 lg:px-8">
        <div class="flex-1">
          <a href="/" class="flex-1 flex w-fit items-center gap-2">
            <img src={~p"/images/logo.svg"} width="36" />
            <span class="text-sm font-semibold">v{Application.spec(:phoenix, :vsn)}</span>
          </a>
        </div>
        <div class="flex-none">
          <ul class="flex flex-column px-1 space-x-4 items-center">
            <li>
              <a href="https://phoenixframework.org/" class="btn btn-ghost">Website</a>
            </li>
            <li>
              <a href="https://github.com/phoenixframework/phoenix" class="btn btn-ghost">GitHub</a>
            </li>
            <li>
              <.theme_toggle />
            </li>
            <li>
              <a href="https://hexdocs.pm/phoenix/overview.html" class="btn btn-primary">
                Get Started <span aria-hidden="true">&rarr;</span>
              </a>
            </li>
          </ul>
        </div>
      </header>

      <main class="px-4 py-20 sm:px-6 lg:px-8">
        <div class="mx-auto max-w-2xl space-y-4">
          {render_slot(@inner_block)}
        </div>
      </main>

      <.flash_group flash={@flash} />
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
      <div id={@id} aria-live="polite">
        <.flash kind={:info} flash={@flash} />
        <.flash kind={:error} flash={@flash} />

        <.flash
          id="client-error"
          kind={:error}
          title={gettext("We can't find the internet")}
          phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
          phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
          hidden
        >
          {gettext("Attempting to reconnect")}
          <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
        </.flash>

        <.flash
          id="server-error"
          kind={:error}
          title={gettext("Something went wrong!")}
          phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
          phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
          hidden
        >
          {gettext("Attempting to reconnect")}
          <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
        </.flash>
      </div>
      \"\"\"
    end

    @doc \"\"\"
    Provides dark vs light theme toggle based on themes defined in app.css.

    See <head> in root.html.heex which applies the theme before page load.
    \"\"\"
    def theme_toggle(assigns) do
      ~H\"\"\"
      <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
        <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

        <button
          class="flex p-2 cursor-pointer w-1/3"
          phx-click={JS.dispatch("phx:set-theme")}
          data-phx-theme="system"
        >
          <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
        </button>

        <button
          class="flex p-2 cursor-pointer w-1/3"
          phx-click={JS.dispatch("phx:set-theme")}
          data-phx-theme="light"
        >
          <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
        </button>

        <button
          class="flex p-2 cursor-pointer w-1/3"
          phx-click={JS.dispatch("phx:set-theme")}
          data-phx-theme="dark"
        >
          <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
        </button>
      </div>
      \"\"\"
    end
    """
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
        <.live_title default="#{app_module}" suffix=" · Phoenix Framework">
          {assigns[:page_title]}
        </.live_title>
        <link phx-track-static rel="stylesheet" href={~p"/assets/css/app.css"} />
        <script defer phx-track-static type="text/javascript" src={~p"/assets/js/app.js"}>
        </script>
        <script>
          (() => {
            const setTheme = (theme) => {
              if (theme === "system") {
                localStorage.removeItem("phx:theme");
                document.documentElement.removeAttribute("data-theme");
              } else {
                localStorage.setItem("phx:theme", theme);
                document.documentElement.setAttribute("data-theme", theme);
              }
            };
            if (!document.documentElement.hasAttribute("data-theme")) {
              setTheme(localStorage.getItem("phx:theme") || "system");
            }
            window.addEventListener("storage", (e) => e.key === "phx:theme" && setTheme(e.newValue || "system"));
            window.addEventListener("phx:set-theme", (e) => setTheme(e.target.dataset.phxTheme));
          })();
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

  defp create_logo_svg(igniter) do
    content = """
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 71 48" fill="currentColor" aria-hidden="true">
      <path
        d="m26.371 33.477-.552-.1c-3.92-.729-6.397-3.1-7.57-6.829-.733-2.324.597-4.035 3.035-4.148 1.995-.092 3.362 1.055 4.57 2.39 1.557 1.72 2.984 3.558 4.514 5.305 2.202 2.515 4.797 4.134 8.347 3.634 3.183-.448 5.958-1.725 8.371-3.828.363-.316.761-.592 1.144-.886l-.241-.284c-2.027.63-4.093.841-6.205.735-3.195-.16-6.24-.828-8.964-2.582-2.486-1.601-4.319-3.746-5.19-6.611-.704-2.315.736-3.934 3.135-3.6.948.133 1.746.56 2.463 1.165.583.493 1.143 1.015 1.738 1.493 2.8 2.25 6.712 2.375 10.265-.068-5.842-.026-9.817-3.24-13.308-7.313-1.366-1.594-2.7-3.216-4.095-4.785-2.698-3.036-5.692-5.71-9.79-6.623C12.8-.623 7.745.14 2.893 2.361 1.926 2.804.997 3.319 0 4.149c.494 0 .763.006 1.032 0 2.446-.064 4.28 1.023 5.602 3.024.962 1.457 1.415 3.104 1.761 4.798.513 2.515.247 5.078.544 7.605.761 6.494 4.08 11.026 10.26 13.346 2.267.852 4.591 1.135 7.172.555ZM10.751 3.852c-.976.246-1.756-.148-2.56-.962 1.377-.343 2.592-.476 3.897-.528-.107.848-.607 1.306-1.336 1.49Zm32.002 37.924c-.085-.626-.62-.901-1.04-1.228-1.857-1.446-4.03-1.958-6.333-2-1.375-.026-2.735-.128-4.031-.61-.595-.22-1.26-.505-1.244-1.272.015-.78.693-1 1.31-1.184.505-.15 1.026-.247 1.6-.382-1.46-.936-2.886-1.065-4.787-.3-2.993 1.202-5.943 1.06-8.926-.017-1.684-.608-3.179-1.563-4.735-2.408l-.077.057c1.29 2.115 3.034 3.817 5.004 5.271 3.793 2.8 7.936 4.471 12.784 3.73A66.714 66.714 0 0 1 37 40.877c1.98-.16 3.866.398 5.753.899Zm-9.14-30.345c-.105-.076-.206-.266-.42-.069 1.745 2.36 3.985 4.098 6.683 5.193 4.354 1.767 8.773 2.07 13.293.51 3.51-1.21 6.033-.028 7.343 3.38.19-3.955-2.137-6.837-5.843-7.401-2.084-.318-4.01.373-5.962.94-5.434 1.575-10.485.798-15.094-2.553Zm27.085 15.425c.708.059 1.416.123 2.124.185-1.6-1.405-3.55-1.517-5.523-1.404-3.003.17-5.167 1.903-7.14 3.972-1.739 1.824-3.31 3.87-5.903 4.604.043.078.054.117.066.117.35.005.699.021 1.047.005 3.768-.17 7.317-.965 10.14-3.7.89-.86 1.685-1.817 2.544-2.71.716-.746 1.584-1.159 2.645-1.07Zm-8.753-4.67c-2.812.246-5.254 1.409-7.548 2.943-1.766 1.18-3.654 1.738-5.776 1.37-.374-.066-.75-.114-1.124-.17l-.013.156c.135.07.265.151.405.207.354.14.702.308 1.07.395 4.083.971 7.992.474 11.516-1.803 2.221-1.435 4.521-1.707 7.013-1.336.252.038.503.083.756.107.234.022.479.255.795.003-2.179-1.574-4.526-2.096-7.094-1.872Zm-10.049-9.544c1.475.051 2.943-.142 4.486-1.059-.452.04-.643.04-.827.076-2.126.424-4.033-.04-5.733-1.383-.623-.493-1.257-.974-1.889-1.457-2.503-1.914-5.374-2.555-8.514-2.5.05.154.054.26.108.315 3.417 3.455 7.371 5.836 12.369 6.008Zm24.727 17.731c-2.114-2.097-4.952-2.367-7.578-.537 1.738.078 3.043.632 4.101 1.728a13 13 0 0 0 1.182 1.106c1.6 1.29 4.311 1.352 5.896.155-1.861-.726-1.861-.726-3.601-2.452Zm-21.058 16.06c-1.858-3.46-4.981-4.24-8.59-4.008a9.667 9.667 0 0 1 2.977 1.39c.84.586 1.547 1.311 2.243 2.055 1.38 1.473 3.534 2.376 4.962 2.07-.656-.412-1.238-.848-1.592-1.507Zl-.006.006-.036-.004.021.018.012.053Za.127.127 0 0 0 .015.043c.005.008.038 0 .058-.002Zl-.008.01.005.026.024.014Z"
        fill="#FD4F00"
      />
    </svg>
    """

    Igniter.create_new_file(igniter, "priv/static/images/logo.svg", content, on_exists: :skip)
  end

  defp create_daisy_css(igniter) do
    content = daisy_css_content()

    Igniter.create_new_file(igniter, "assets/css/phx-daisy.css", content, on_exists: :skip)
  end

  defp daisy_css_content do
    """
    /* daisyUI Tailwind Plugin. You can update this file by fetching the latest version with:
       curl -sLO https://github.com/saadeghi/daisyui/releases/latest/download/daisyui.js
       Make sure to look at the daisyUI changelog: https://daisyui.com/docs/changelog/ */
    @plugin "../vendor/daisyui" {
      themes: false;
    }

    /* daisyUI theme plugin. You can update this file by fetching the latest version with:
      curl -sLO https://github.com/saadeghi/daisyui/releases/latest/download/daisyui-theme.js
      We ship with two themes, a light one inspired on Phoenix colours and a dark one inspired
      on Elixir colours. Build your own at: https://daisyui.com/theme-generator/ */
    @plugin "../vendor/daisyui-theme" {
      name: "dark";
      default: false;
      prefersdark: true;
      color-scheme: "dark";
      --color-base-100: oklch(30.33% 0.016 252.42);
      --color-base-200: oklch(25.26% 0.014 253.1);
      --color-base-300: oklch(20.15% 0.012 254.09);
      --color-base-content: oklch(97.807% 0.029 256.847);
      --color-primary: oklch(58% 0.233 277.117);
      --color-primary-content: oklch(96% 0.018 272.314);
      --color-secondary: oklch(58% 0.233 277.117);
      --color-secondary-content: oklch(96% 0.018 272.314);
      --color-accent: oklch(60% 0.25 292.717);
      --color-accent-content: oklch(96% 0.016 293.756);
      --color-neutral: oklch(37% 0.044 257.287);
      --color-neutral-content: oklch(98% 0.003 247.858);
      --color-info: oklch(58% 0.158 241.966);
      --color-info-content: oklch(97% 0.013 236.62);
      --color-success: oklch(60% 0.118 184.704);
      --color-success-content: oklch(98% 0.014 180.72);
      --color-warning: oklch(66% 0.179 58.318);
      --color-warning-content: oklch(98% 0.022 95.277);
      --color-error: oklch(58% 0.253 17.585);
      --color-error-content: oklch(96% 0.015 12.422);
      --radius-selector: 0.25rem;
      --radius-field: 0.25rem;
      --radius-box: 0.5rem;
      --size-selector: 0.21875rem;
      --size-field: 0.21875rem;
      --border: 1.5px;
      --depth: 1;
      --noise: 0;
    }

    @plugin "../vendor/daisyui-theme" {
      name: "light";
      default: true;
      prefersdark: false;
      color-scheme: "light";
      --color-base-100: oklch(98% 0 0);
      --color-base-200: oklch(96% 0.001 286.375);
      --color-base-300: oklch(92% 0.004 286.32);
      --color-base-content: oklch(21% 0.006 285.885);
      --color-primary: oklch(70% 0.213 47.604);
      --color-primary-content: oklch(98% 0.016 73.684);
      --color-secondary: oklch(55% 0.027 264.364);
      --color-secondary-content: oklch(98% 0.002 247.839);
      --color-accent: oklch(0% 0 0);
      --color-accent-content: oklch(100% 0 0);
      --color-neutral: oklch(44% 0.017 285.786);
      --color-neutral-content: oklch(98% 0 0);
      --color-info: oklch(62% 0.214 259.815);
      --color-info-content: oklch(97% 0.014 254.604);
      --color-success: oklch(70% 0.14 182.503);
      --color-success-content: oklch(98% 0.014 180.72);
      --color-warning: oklch(66% 0.179 58.318);
      --color-warning-content: oklch(98% 0.022 95.277);
      --color-error: oklch(58% 0.253 17.585);
      --color-error-content: oklch(96% 0.015 12.422);
      --radius-selector: 0.25rem;
      --radius-field: 0.25rem;
      --radius-box: 0.5rem;
      --size-selector: 0.21875rem;
      --size-field: 0.21875rem;
      --border: 1.5px;
      --depth: 1;
      --noise: 0;
    }

    /* Use the data attribute for dark mode */
    @custom-variant dark (&:where([data-theme=dark], [data-theme=dark] *));
    """
  end

  defp download_vendor_file(igniter, filename) do
    path = "assets/vendor/#{filename}"

    if vendor_file_exists?(igniter, path) do
      igniter
    else
      fetch_and_create_vendor_file(igniter, path, filename)
    end
  end

  defp vendor_file_exists?(igniter, path) do
    match?({:ok, _}, Rewrite.source(igniter.rewrite, path)) or File.exists?(path)
  end

  defp fetch_and_create_vendor_file(igniter, path, filename) do
    url = "#{@daisyui_base_url}/#{filename}"

    case fetch_url(url) do
      {:ok, body} ->
        Igniter.create_new_file(igniter, path, body, on_exists: :skip)

      {:error, reason} ->
        Igniter.add_notice(
          igniter,
          """
          Could not download #{filename} from #{url}: #{reason}

          Please download it manually:
            curl -sLo #{path} #{url}
          """
        )
    end
  end

  defp fetch_url(url) do
    Application.ensure_all_started(:inets)
    Application.ensure_all_started(:ssl)
    Application.ensure_all_started(:public_key)

    url_charlist = String.to_charlist(url)

    http_opts = [
      ssl: [
        verify: :verify_peer,
        cacerts: :public_key.cacerts_get(),
        customize_hostname_check: [
          match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
        ]
      ],
      autoredirect: true
    ]

    case :httpc.request(:get, {url_charlist, []}, http_opts, body_format: :binary) do
      {:ok, {{_, 200, _}, _headers, body}} -> {:ok, body}
      {:ok, {{_, status, _}, _, _}} -> {:error, "HTTP #{status}"}
      {:error, reason} -> {:error, inspect(reason)}
    end
  end
end
