defmodule Mix.Tasks.Phx.Install.Heroicons do
  @moduledoc """
  Sets up Heroicon rendering for a Phoenix application.

  This task sets up:
  - `heroicons` dependency (SVG icon set from Tailwind Labs)
  - `assets/vendor/heroicons.js` — Tailwind CSS plugin that generates icon classes
  - `@plugin` import in `assets/css/app.css`
  - `icon/1` component in CoreComponents

  ## Usage

      mix phx.install.heroicons

  ## Prerequisites

  This task requires the assets pipeline (Tailwind CSS) to be installed.
  It is typically called by `mix phx.install` with the `--assets` flag (default: true).

  This task is typically called by `mix phx.install` rather than directly.
  """
  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :phoenix,
      example: "mix phx.install.heroicons"
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    web_module = Igniter.Libs.Phoenix.web_module(igniter)

    igniter
    |> add_heroicons_dep()
    |> create_heroicons_js()
    |> append_plugin_to_app_css()
    |> add_icon_component(web_module)
  end

  defp add_heroicons_dep(igniter) do
    Igniter.Project.Deps.add_dep(
      igniter,
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.2.0",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1}
    )
  end

  defp create_heroicons_js(igniter) do
    Igniter.create_new_file(igniter, "assets/vendor/heroicons.js", heroicons_js(),
      on_exists: :skip
    )
  end

  defp append_plugin_to_app_css(igniter) do
    path = "assets/css/app.css"
    plugin_line = ~s|@plugin "../vendor/heroicons";|

    case Rewrite.source(igniter.rewrite, path) do
      {:ok, source} ->
        content = Rewrite.Source.get(source, :content)

        if String.contains?(content, plugin_line) do
          igniter
        else
          updated_content =
            String.replace(
              content,
              ~s|@import "tailwindcss";|,
              ~s|@import "tailwindcss";\n#{plugin_line}|
            )

          updated_source = Rewrite.Source.update(source, :content, updated_content)
          %{igniter | rewrite: Rewrite.update!(igniter.rewrite, updated_source)}
        end

      {:error, _} ->
        igniter
    end
  end

  defp add_icon_component(igniter, web_module) do
    core_components_module = Module.concat(web_module, CoreComponents)

    icon_code = """
    @doc \"\"\"
    Renders a [Heroicon](https://heroicons.com).

    Heroicons come in three styles – outline, solid, and mini.
    By default, the outline style is used, but solid and mini may
    be applied by using the `-solid` and `-mini` suffix.

    You can customise the size and colours of the icons by setting
    width, height, and background colour classes.

    Icons are extracted from the `deps/heroicons` directory and bundled within
    your compiled app.css by the plugin in `assets/vendor/heroicons.js`.

    ## Examples

        <.icon name="hero-x-mark" />
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
    \"\"\"
    attr :name, :string, required: true
    attr :class, :any, default: "size-4"

    def icon(%{name: "hero-" <> _} = assigns) do
      ~H\"\"\"
      <span class={[@name, @class]} />
      \"\"\"
    end
    """

    Igniter.Project.Module.find_and_update_module!(
      igniter,
      core_components_module,
      fn zipper ->
        case Igniter.Code.Function.move_to_def(zipper, :icon, 1) do
          {:ok, _} -> {:ok, zipper}
          :error -> {:ok, Igniter.Code.Common.add_code(zipper, icon_code)}
        end
      end
    )
  end

  defp heroicons_js do
    ~S"""
    const plugin = require("tailwindcss/plugin")
    const fs = require("fs")
    const path = require("path")

    module.exports = plugin(function({matchComponents, theme}) {
      let iconsDir = path.join(__dirname, "../../deps/heroicons/optimized")
      let values = {}
      let icons = [
        ["", "/24/outline"],
        ["-solid", "/24/solid"],
        ["-mini", "/20/solid"],
        ["-micro", "/16/solid"]
      ]
      icons.forEach(([suffix, dir]) => {
        fs.readdirSync(path.join(iconsDir, dir)).forEach(file => {
          let name = path.basename(file, ".svg") + suffix
          values[name] = {name, fullPath: path.join(iconsDir, dir, file)}
        })
      })
      matchComponents({
        "hero": ({name, fullPath}) => {
          let content = fs.readFileSync(fullPath).toString().replace(/\r?\n|\r/g, "")
          content = encodeURIComponent(content)
          let size = theme("spacing.6")
          if (name.endsWith("-mini")) {
            size = theme("spacing.5")
          } else if (name.endsWith("-micro")) {
            size = theme("spacing.4")
          }
          return {
            [`--hero-${name}`]: `url('data:image/svg+xml;utf8,${content}')`,
            "-webkit-mask": `var(--hero-${name})`,
            "mask": `var(--hero-${name})`,
            "mask-repeat": "no-repeat",
            "background-color": "currentColor",
            "vertical-align": "middle",
            "display": "inline-block",
            "width": size,
            "height": size
          }
        }
      }, {values})
    })
    """
  end
end
