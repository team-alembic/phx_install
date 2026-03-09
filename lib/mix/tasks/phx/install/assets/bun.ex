defmodule Mix.Tasks.Phx.Install.Assets.Bun do
  @shortdoc "Sets up JavaScript bundling with Bun"
  @moduledoc """
  Sets up JavaScript bundling with Bun.

  This task sets up:
  - `bun` dependency (hex package for managing the bun runtime)
  - `assets/js/app.ts` or `assets/js/app.js` - entry point using npm packages
  - `assets/package.json` - workspace configuration for Phoenix dependencies
  - Bun configuration profiles in config.exs
  - Bun JS watcher in dev.exs

  ## Usage

      mix phx.install.assets.bun

  ## Options

  - `--lang` - Language for the entry point: "js" (default) or "ts"
  - `--tailwind` / `--no-tailwind` - Include Tailwind CSS npm packages in package.json (default: true)
  - `--js-test` / `--no-js-test` - Add `bun test` to the `mix test` alias (default: false)

  This task is typically composed by `mix phx.install.assets` rather than called directly.
  """
  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :phoenix,
      example: "mix phx.install.assets.bun",
      adds_deps: [{:bun, "~> 2.0"}],
      schema: [lang: :string, tailwind: :boolean, js_test: :boolean],
      defaults: [lang: "js", tailwind: true, js_test: false]
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    app_name = Igniter.Project.Application.app_name(igniter)
    web_module = Igniter.Libs.Phoenix.web_module(igniter)
    endpoint_module = Module.concat(web_module, Endpoint)

    opts = igniter.args.options
    ts? = opts[:lang] == "ts"
    tailwind? = opts[:tailwind] != false
    js_test? = opts[:js_test] == true

    igniter
    |> Igniter.Project.Deps.add_dep({:bun, "~> 2.0"}, on_exists: :skip)
    |> set_runtime_dep()
    |> create_app_entry(ts?)
    |> create_package_json(tailwind?)
    |> configure_bun(app_name, ts?)
    |> configure_watcher(app_name, endpoint_module)
    |> maybe_add_test_alias(js_test?)
  end

  defp set_runtime_dep(igniter) do
    Igniter.Project.Deps.set_dep_option(
      igniter,
      :bun,
      :runtime,
      Sourceror.parse_string!("Mix.env() == :dev")
    )
  end

  defp create_app_entry(igniter, false) do
    content = """
    import "phoenix_html"
    import {Socket} from "phoenix"
    import {LiveSocket} from "phoenix_live_view"
    import topbar from "topbar"

    const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
    const liveSocket = new LiveSocket("/live", Socket, {
      longPollFallbackMs: 2500,
      params: {_csrf_token: csrfToken}
    })

    // Show progress bar on live navigation and form submits
    topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
    window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
    window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

    // connect if there are any LiveViews on the page
    liveSocket.connect()

    // expose liveSocket on window for web console debug logs and latency simulation:
    // >> liveSocket.enableDebug()
    // >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
    // >> liveSocket.disableLatencySim()
    window.liveSocket = liveSocket

    if (process.env.NODE_ENV === "development") {
      window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
        reloader.enableServerLogs()

        let keyDown
        window.addEventListener("keydown", e => keyDown = e.key)
        window.addEventListener("keyup", _e => keyDown = null)
        window.addEventListener("click", e => {
          if(keyDown === "c"){
            e.preventDefault()
            e.stopImmediatePropagation()
            reloader.openEditorAtCaller(e.target)
          } else if(keyDown === "d"){
            e.preventDefault()
            e.stopImmediatePropagation()
            reloader.openEditorAtDef(e.target)
          }
        }, true)

        window.liveReloader = reloader
      })
    }
    """

    Igniter.create_new_file(igniter, "assets/js/app.js", content, on_exists: :skip)
  end

  defp create_app_entry(igniter, true) do
    content = """
    import "phoenix_html"
    import {Socket} from "phoenix"
    import {LiveSocket} from "phoenix_live_view"
    import topbar from "topbar"

    declare global {
      interface Window {
        liveSocket: LiveSocket
        liveReloader: unknown
      }
    }

    function connectLiveSocket(): LiveSocket {
      const csrfToken = document.querySelector<HTMLMetaElement>("meta[name='csrf-token']")!.content
      const liveSocket = new LiveSocket("/live", Socket, {
        longPollFallbackMs: 2500,
        params: {_csrf_token: csrfToken},
      })
      liveSocket.connect()
      return liveSocket
    }

    function setupTopbar() {
      topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
      window.addEventListener("phx:page-loading-start", () => topbar.show(300))
      window.addEventListener("phx:page-loading-stop", () => topbar.hide())
    }

    function setupDevTools() {
      window.addEventListener("phx:live_reload:attached", ({detail: reloader}: CustomEvent) => {
        reloader.enableServerLogs()

        let keyDown: string | null = null
        window.addEventListener("keydown", (e: KeyboardEvent) => keyDown = e.key)
        window.addEventListener("keyup", () => keyDown = null)
        window.addEventListener("click", (e: MouseEvent) => {
          if (keyDown === "c") {
            e.preventDefault()
            e.stopImmediatePropagation()
            reloader.openEditorAtCaller(e.target)
          } else if (keyDown === "d") {
            e.preventDefault()
            e.stopImmediatePropagation()
            reloader.openEditorAtDef(e.target)
          }
        }, true)

        window.liveReloader = reloader
      })
    }

    setupTopbar()
    window.liveSocket = connectLiveSocket()

    if (process.env.NODE_ENV === "development") {
      setupDevTools()
    }
    """

    Igniter.create_new_file(igniter, "assets/js/app.ts", content, on_exists: :skip)
  end

  defp create_package_json(igniter, tailwind?) do
    tailwind_deps =
      if tailwind? do
        """
        ,
            "tailwindcss": "^4.1.0",
            "@tailwindcss/cli": "^4.1.0"
        """
      else
        ""
      end

    content = """
    {
      "workspaces": [
        "../deps/*"
      ],
      "dependencies": {
        "phoenix": "workspace:*",
        "phoenix_html": "workspace:*",
        "phoenix_live_view": "workspace:*",
        "topbar": "^3.0.0"#{String.trim_trailing(tailwind_deps)}
      }
    }
    """

    Igniter.create_new_file(igniter, "assets/package.json", content, on_exists: :skip)
  end

  defp configure_bun(igniter, _app_name, ts?) do
    entry_point = if ts?, do: "js/app.ts", else: "js/app.js"

    assets_config =
      {:code,
       Sourceror.parse_string!("""
       [args: [], cd: Path.expand("../assets", __DIR__)]
       """)}

    js_config =
      {:code,
       Sourceror.parse_string!("""
       [
         args: ~w(build #{entry_point} --outdir=../priv/static/assets/js --external /fonts/* --external /images/*),
         cd: Path.expand("../assets", __DIR__)
       ]
       """)}

    igniter
    |> Igniter.Project.Config.configure("config.exs", :bun, [:version], "1.2.15")
    |> Igniter.Project.Config.configure(
      "config.exs",
      :bun,
      [:assets],
      assets_config,
      updater: fn zipper -> {:ok, zipper} end
    )
    |> Igniter.Project.Config.configure(
      "config.exs",
      :bun,
      [:js],
      js_config,
      updater: fn zipper -> {:ok, zipper} end
    )
  end

  defp configure_watcher(igniter, app_name, endpoint_module) do
    watcher_value =
      {:code,
       Sourceror.parse_string!("{Bun, :install_and_run, [:js, ~w(--sourcemap=inline --watch)]}")}

    Igniter.Project.Config.configure(
      igniter,
      "dev.exs",
      app_name,
      [endpoint_module, :watchers, :bun_js],
      watcher_value,
      updater: fn zipper -> {:ok, zipper} end
    )
  end

  defp maybe_add_test_alias(igniter, false), do: igniter

  defp maybe_add_test_alias(igniter, true) do
    Igniter.Project.TaskAliases.add_alias(
      igniter,
      "test",
      ["bun assets test", "test"],
      if_exists: {:append, "bun assets test"}
    )
  end
end
