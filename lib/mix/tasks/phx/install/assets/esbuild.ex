defmodule Mix.Tasks.Phx.Install.Assets.Esbuild do
  @shortdoc "Sets up JavaScript bundling with esbuild"
  @moduledoc """
  Sets up JavaScript bundling with esbuild.

  This task sets up:
  - `esbuild` dependency
  - `assets/js/app.js` or `assets/js/app.ts` - JavaScript/TypeScript entry point
  - `assets/vendor/topbar.js` - Progress indicator for LiveView
  - esbuild configuration in config.exs
  - esbuild watcher in dev.exs

  ## Usage

      mix phx.install.assets.esbuild
      mix phx.install.assets.esbuild --lang ts

  ## Options

  - `--lang` - Language for the entry point: "js" (default) or "ts"

  This task is typically composed by `mix phx.install.assets` rather than called directly.
  """
  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :phoenix,
      example: "mix phx.install.assets.esbuild",
      adds_deps: [{:esbuild, "~> 0.10"}],
      schema: [lang: :string],
      defaults: [lang: "js"]
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    app_name = Igniter.Project.Application.app_name(igniter)
    web_module = Igniter.Libs.Phoenix.web_module(igniter)
    endpoint_module = Module.concat(web_module, Endpoint)

    opts = igniter.args.options
    ts? = opts[:lang] == "ts"

    igniter
    |> Igniter.Project.Deps.add_dep({:esbuild, "~> 0.10"}, on_exists: :skip)
    |> set_runtime_dep()
    |> create_app_entry(web_module, ts?)
    |> create_topbar_js()
    |> configure_esbuild(app_name, ts?)
    |> configure_watcher(app_name, endpoint_module)
  end

  defp set_runtime_dep(igniter) do
    Igniter.Project.Deps.set_dep_option(
      igniter,
      :esbuild,
      :runtime,
      Sourceror.parse_string!("Mix.env() == :dev")
    )
  end

  defp create_app_entry(igniter, _web_module, false) do
    content = """
    // If you want to use Phoenix channels, run `mix help phx.gen.channel`
    // to get started and then uncomment the line below.
    // import "./user_socket.js"

    // You can include dependencies in two ways.
    //
    // The simplest option is to put them in assets/vendor and
    // import them using relative paths:
    //
    //     import "../vendor/some-package.js"
    //
    // Alternatively, you can `npm install some-package --prefix assets` and import
    // them using a path starting with the package name:
    //
    //     import "some-package"
    //

    // Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
    import "phoenix_html"
    // Establish Phoenix Socket and LiveView configuration.
    import {Socket} from "phoenix"
    import {LiveSocket} from "phoenix_live_view"
    import topbar from "../vendor/topbar"

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

    // The lines below enable quality of life phoenix_live_reload
    // development features:
    //
    //     1. stream server logs to the browser console
    //     2. click on elements to jump to their definitions in your code editor
    //
    if (process.env.NODE_ENV === "development") {
      window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
        // Enable server log streaming to client.
        // Disable with reloader.disableServerLogs()
        reloader.enableServerLogs()

        // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
        //
        //   * click with "c" key pressed to open at caller location
        //   * click with "d" key pressed to open at function component definition location
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

  defp create_app_entry(igniter, _web_module, true) do
    content = """
    import "phoenix_html"
    import {Socket} from "phoenix"
    import {LiveSocket} from "phoenix_live_view"
    import topbar from "../vendor/topbar"

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

  defp create_topbar_js(igniter) do
    content = """
    /**
     * @license MIT
     * topbar 3.0.0
     * http://buunguyen.github.io/topbar
     * Copyright (c) 2024 Buu Nguyen
     */
    (function (window, document) {
      "use strict";

      var canvas,
        currentProgress,
        showing,
        progressTimerId = null,
        fadeTimerId = null,
        delayTimerId = null,
        addEvent = function (elem, type, handler) {
          if (elem.addEventListener) elem.addEventListener(type, handler, false);
          else if (elem.attachEvent) elem.attachEvent("on" + type, handler);
          else elem["on" + type] = handler;
        },
        options = {
          autoRun: true,
          barThickness: 3,
          barColors: {
            0: "rgba(26,  188, 156, .9)",
            ".25": "rgba(52,  152, 219, .9)",
            ".50": "rgba(241, 196, 15,  .9)",
            ".75": "rgba(230, 126, 34,  .9)",
            "1.0": "rgba(211, 84,  0,   .9)",
          },
          shadowBlur: 10,
          shadowColor: "rgba(0,   0,   0,   .6)",
          className: null,
        },
        repaint = function () {
          canvas.width = window.innerWidth;
          canvas.height = options.barThickness * 5; // need space for shadow

          var ctx = canvas.getContext("2d");
          ctx.shadowBlur = options.shadowBlur;
          ctx.shadowColor = options.shadowColor;

          var lineGradient = ctx.createLinearGradient(0, 0, canvas.width, 0);
          for (var stop in options.barColors)
            lineGradient.addColorStop(stop, options.barColors[stop]);
          ctx.lineWidth = options.barThickness;
          ctx.beginPath();
          ctx.moveTo(0, options.barThickness / 2);
          ctx.lineTo(
            Math.ceil(currentProgress * canvas.width),
            options.barThickness / 2
          );
          ctx.strokeStyle = lineGradient;
          ctx.stroke();
        },
        createCanvas = function () {
          canvas = document.createElement("canvas");
          var style = canvas.style;
          style.position = "fixed";
          style.top = style.left = style.right = style.margin = style.padding = 0;
          style.zIndex = 100001;
          style.display = "none";
          if (options.className) canvas.classList.add(options.className);
          addEvent(window, "resize", repaint);
        },
        topbar = {
          config: function (opts) {
            for (var key in opts)
              if (options.hasOwnProperty(key)) options[key] = opts[key];
          },
          show: function (delay) {
            if (showing) return;
            if (delay) {
              if (delayTimerId) return;
              delayTimerId = setTimeout(() => topbar.show(), delay);
            } else {
              showing = true;
              if (fadeTimerId !== null) window.cancelAnimationFrame(fadeTimerId);
              if (!canvas) createCanvas();
              if (!canvas.parentElement) document.body.appendChild(canvas);
              canvas.style.opacity = 1;
              canvas.style.display = "block";
              topbar.progress(0);
              if (options.autoRun) {
                (function loop() {
                  progressTimerId = window.requestAnimationFrame(loop);
                  topbar.progress(
                    "+" + 0.05 * Math.pow(1 - Math.sqrt(currentProgress), 2)
                  );
                })();
              }
            }
          },
          progress: function (to) {
            if (typeof to === "undefined") return currentProgress;
            if (typeof to === "string") {
              to =
                (to.indexOf("+") >= 0 || to.indexOf("-") >= 0
                  ? currentProgress
                  : 0) + parseFloat(to);
            }
            currentProgress = to > 1 ? 1 : to;
            repaint();
            return currentProgress;
          },
          hide: function () {
            clearTimeout(delayTimerId);
            delayTimerId = null;
            if (!showing) return;
            showing = false;
            if (progressTimerId != null) {
              window.cancelAnimationFrame(progressTimerId);
              progressTimerId = null;
            }
            (function loop() {
              if (topbar.progress("+.1") >= 1) {
                canvas.style.opacity -= 0.05;
                if (canvas.style.opacity <= 0.05) {
                  canvas.style.display = "none";
                  fadeTimerId = null;
                  return;
                }
              }
              fadeTimerId = window.requestAnimationFrame(loop);
            })();
          },
        };

      if (typeof module === "object" && typeof module.exports === "object") {
        module.exports = topbar;
      } else if (typeof define === "function" && define.amd) {
        define(function () {
          return topbar;
        });
      } else {
        this.topbar = topbar;
      }
    }.call(this, window, document));
    """

    Igniter.create_new_file(igniter, "assets/vendor/topbar.js", content, on_exists: :skip)
  end

  defp configure_esbuild(igniter, app_name, ts?) do
    entry_point = if ts?, do: "js/app.ts", else: "js/app.js"

    app_config =
      {:code,
       Sourceror.parse_string!("""
       [
         args:
           ~w(#{entry_point} --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/*),
         cd: Path.expand("../assets", __DIR__),
         env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
       ]
       """)}

    igniter
    |> Igniter.Project.Config.configure(
      "config.exs",
      :esbuild,
      [:version],
      "0.25.4"
    )
    |> Igniter.Project.Config.configure(
      "config.exs",
      :esbuild,
      [app_name],
      app_config,
      updater: fn zipper -> {:ok, zipper} end
    )
  end

  defp configure_watcher(igniter, app_name, endpoint_module) do
    watcher_value =
      {:code,
       Sourceror.parse_string!(
         "{Esbuild, :install_and_run, [#{inspect(app_name)}, ~w(--sourcemap=inline --watch)]}"
       )}

    Igniter.Project.Config.configure(
      igniter,
      "dev.exs",
      app_name,
      [endpoint_module, :watchers, :esbuild],
      watcher_value,
      updater: fn zipper -> {:ok, zipper} end
    )
  end
end
