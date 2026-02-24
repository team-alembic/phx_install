defmodule Mix.Tasks.Phx.Install.Assets do
  @moduledoc """
  Sets up the asset build pipeline with esbuild and Tailwind CSS.

  This task sets up:
  - `esbuild` and `tailwind` dependencies
  - `assets/js/app.js` - JavaScript entry point
  - `assets/css/app.css` - Tailwind CSS entry point
  - `assets/vendor/topbar.js` - Progress indicator for LiveView
  - `priv/static/robots.txt` - Robots exclusion file
  - `priv/static/favicon.ico` - Default favicon
  - esbuild and tailwind configuration in config.exs
  - Asset watchers in dev.exs
  - Asset aliases in mix.exs (assets.setup, assets.build, assets.deploy)

  ## Usage

      mix phx.install.assets

  ## Options

  - `--no-esbuild` - Skip JavaScript bundling with esbuild
  - `--no-tailwind` - Skip Tailwind CSS

  This task is typically called by `mix phx.install` rather than directly.
  """
  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :phoenix,
      example: "mix phx.install.assets",
      schema: [
        esbuild: :boolean,
        tailwind: :boolean
      ],
      defaults: [
        esbuild: true,
        tailwind: true
      ]
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    app_name = Igniter.Project.Application.app_name(igniter)
    web_module = Igniter.Libs.Phoenix.web_module(igniter)
    endpoint_module = Module.concat(web_module, Endpoint)

    opts = igniter.args.options
    esbuild? = opts[:esbuild]
    tailwind? = opts[:tailwind]

    igniter
    |> add_esbuild_dep(esbuild?)
    |> add_tailwind_dep(tailwind?)
    |> create_app_js(web_module, esbuild?)
    |> create_app_css(web_module, tailwind?)
    |> create_topbar_js(esbuild?)
    |> create_robots_txt()
    |> create_favicon()
    |> configure_esbuild(app_name, esbuild?)
    |> configure_tailwind(app_name, tailwind?)
    |> configure_watchers(app_name, endpoint_module, esbuild?, tailwind?)
    |> configure_live_reload(app_name, endpoint_module)
    |> add_asset_aliases(app_name, esbuild?, tailwind?)
  end

  defp add_esbuild_dep(igniter, true) do
    Igniter.Project.Deps.add_dep(igniter, {:esbuild, "~> 0.10", runtime: Mix.env() == :dev})
  end

  defp add_esbuild_dep(igniter, false), do: igniter

  defp add_tailwind_dep(igniter, true) do
    Igniter.Project.Deps.add_dep(igniter, {:tailwind, "~> 0.3", runtime: Mix.env() == :dev})
  end

  defp add_tailwind_dep(igniter, false), do: igniter

  defp create_app_js(igniter, _web_module, true) do
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

  defp create_app_js(igniter, _web_module, false), do: igniter

  defp create_app_css(igniter, web_module, true) do
    lib_web_name =
      web_module
      |> Module.split()
      |> List.last()
      |> Macro.underscore()

    content = """
    /* See the Tailwind configuration guide for advanced usage
       https://tailwindcss.com/docs/configuration */

    @import "tailwindcss";
    @source "../js";
    @source "../../lib/#{lib_web_name}";

    /* Add variants based on LiveView classes */
    @custom-variant phx-click-loading (.phx-click-loading&, .phx-click-loading &);
    @custom-variant phx-submit-loading (.phx-submit-loading&, .phx-submit-loading &);
    @custom-variant phx-change-loading (.phx-change-loading&, .phx-change-loading &);

    /* Make LiveView wrapper divs transparent for layout */
    [data-phx-session], [data-phx-teleported-src] { display: contents }

    /* This file is for your main application CSS */
    """

    Igniter.create_new_file(igniter, "assets/css/app.css", content, on_exists: :skip)
  end

  defp create_app_css(igniter, _web_module, false), do: igniter

  defp create_topbar_js(igniter, true) do
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

  defp create_topbar_js(igniter, false), do: igniter

  defp create_robots_txt(igniter) do
    content = """
    # See https://www.robotstxt.org/robotstxt.html for documentation on how to use the robots.txt file
    #
    # To ban all spiders from the entire site uncomment the next two lines:
    # User-agent: *
    # Disallow: /
    """

    Igniter.create_new_file(igniter, "priv/static/robots.txt", content, on_exists: :skip)
  end

  defp create_favicon(igniter) do
    # Create a minimal valid favicon (1x1 pixel ICO)
    # This is a placeholder - users should replace with their own favicon
    favicon_bytes =
      <<0, 0, 1, 0, 1, 0, 1, 1, 0, 0, 1, 0, 24, 0, 48, 0, 0, 0, 22, 0, 0, 0, 40, 0, 0, 0, 1, 0, 0,
        0, 2, 0, 0, 0, 1, 0, 24, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 255, 0, 0, 0, 0, 0>>

    Igniter.create_new_file(igniter, "priv/static/favicon.ico", favicon_bytes, on_exists: :skip)
  end

  defp configure_esbuild(igniter, app_name, true) do
    app_config =
      {:code,
       Sourceror.parse_string!("""
       [
         args:
           ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/*),
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

  defp configure_esbuild(igniter, _app_name, false), do: igniter

  defp configure_tailwind(igniter, app_name, true) do
    app_config =
      {:code,
       Sourceror.parse_string!("""
       [
         args: ~w(
           --input=assets/css/app.css
           --output=priv/static/assets/css/app.css
         ),
         cd: Path.expand("..", __DIR__)
       ]
       """)}

    igniter
    |> Igniter.Project.Config.configure(
      "config.exs",
      :tailwind,
      [:version],
      "4.1.12"
    )
    |> Igniter.Project.Config.configure(
      "config.exs",
      :tailwind,
      [app_name],
      app_config,
      updater: fn zipper -> {:ok, zipper} end
    )
  end

  defp configure_tailwind(igniter, _app_name, false), do: igniter

  defp configure_watchers(igniter, app_name, endpoint_module, esbuild?, tailwind?) do
    watchers = build_watchers(app_name, esbuild?, tailwind?)

    if watchers == [] do
      igniter
    else
      watchers_code = {:code, Sourceror.parse_string!(inspect(watchers))}

      Igniter.Project.Config.configure(
        igniter,
        "dev.exs",
        app_name,
        [endpoint_module, :watchers],
        watchers_code,
        updater: fn zipper -> {:ok, zipper} end
      )
    end
  end

  defp build_watchers(app_name, esbuild?, tailwind?) do
    esbuild_watcher =
      if esbuild? do
        [{:esbuild, {Esbuild, :install_and_run, [app_name, ~w(--sourcemap=inline --watch)]}}]
      else
        []
      end

    tailwind_watcher =
      if tailwind? do
        [{:tailwind, {Tailwind, :install_and_run, [app_name, ~w(--watch)]}}]
      else
        []
      end

    esbuild_watcher ++ tailwind_watcher
  end

  defp configure_live_reload(igniter, app_name, endpoint_module) do
    live_reload_config =
      {:code,
       Sourceror.parse_string!("""
       [
         web_console_logger: true,
         patterns: [
           ~r"priv/static/(?!uploads/).*\\.(js|css|png|jpeg|jpg|gif|svg)$",
           ~r"lib/.*_web/router\\.ex$",
           ~r"lib/.*_web/(controllers|live|components)/.*\\.(ex|heex)$"
         ]
       ]
       """)}

    Igniter.Project.Config.configure(
      igniter,
      "dev.exs",
      app_name,
      [endpoint_module, :live_reload],
      live_reload_config,
      updater: fn zipper -> {:ok, zipper} end
    )
  end

  defp add_asset_aliases(igniter, app_name, esbuild?, tailwind?) do
    asset_builders = build_asset_builders(esbuild?, tailwind?)

    if asset_builders == [] do
      igniter
    else
      setup_tasks = Enum.map(asset_builders, &"#{&1}.install --if-missing")
      build_tasks = ["compile" | Enum.map(asset_builders, &"#{&1} #{app_name}")]
      deploy_tasks = Enum.map(asset_builders, &"#{&1} #{app_name} --minify") ++ ["phx.digest"]

      igniter
      |> add_alias_if_missing("assets.setup", setup_tasks)
      |> add_alias_if_missing("assets.build", build_tasks)
      |> add_alias_if_missing("assets.deploy", deploy_tasks)
      |> update_setup_alias(asset_builders)
    end
  end

  defp build_asset_builders(esbuild?, tailwind?) do
    esbuild = if esbuild?, do: ["esbuild"], else: []
    tailwind = if tailwind?, do: ["tailwind"], else: []
    esbuild ++ tailwind
  end

  defp add_alias_if_missing(igniter, alias_name, tasks) do
    Igniter.Project.TaskAliases.add_alias(igniter, alias_name, tasks, if_exists: :ignore)
  end

  defp update_setup_alias(igniter, _asset_builders) do
    igniter
    |> Igniter.Project.TaskAliases.add_alias(
      "setup",
      ["deps.get", "assets.setup", "assets.build"],
      if_exists: {:append, "assets.setup"}
    )
    |> Igniter.Project.TaskAliases.add_alias(
      "setup",
      ["deps.get", "assets.setup", "assets.build"],
      if_exists: {:append, "assets.build"}
    )
  end
end
