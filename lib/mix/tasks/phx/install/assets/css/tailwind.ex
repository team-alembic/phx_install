defmodule Mix.Tasks.Phx.Install.Assets.Css.Tailwind do
  @shortdoc "Sets up Tailwind CSS"
  @moduledoc """
  Sets up Tailwind CSS for a Phoenix application.

  Creates `assets/css/phx-tailwind.css` with the Tailwind foundation
  (import, source directives, LiveView custom variants) and appends an
  `@import` line to `assets/css/app.css`.

  Then dynamically composes a bundler-specific runner task based on
  the `--bundler` flag:

  - `phx.install.assets.css.tailwind.esbuild` - uses the `tailwind` hex package

  To add support for a new bundler, implement a task at
  `phx.install.assets.css.tailwind.<bundler_name>`.

  ## Usage

      mix phx.install.assets.css.tailwind
      mix phx.install.assets.css.tailwind --bundler esbuild

  ## Options

  - `--bundler` - Which bundler is in use: "esbuild" (default)

  This task is typically composed by `mix phx.install.assets.css` rather than called directly.
  """
  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def info(argv, _composing_task) do
    {parsed, _, _} = OptionParser.parse(argv, strict: [bundler: :string])
    bundler = Keyword.get(parsed, :bundler, "esbuild")

    %Igniter.Mix.Task.Info{
      group: :phoenix,
      example: "mix phx.install.assets.css.tailwind",
      schema: [bundler: :string],
      defaults: [bundler: "esbuild"],
      composes: ["phx.install.assets.css.tailwind.#{bundler}"]
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    web_module = Igniter.Libs.Phoenix.web_module(igniter)

    opts = igniter.args.options
    bundler = opts[:bundler] || "esbuild"

    igniter
    |> create_tailwind_css(web_module)
    |> PhxInstall.append_css_import(~s|@import "./phx-tailwind.css";|)
    |> Igniter.compose_task("phx.install.assets.css.tailwind.#{bundler}")
  end

  defp create_tailwind_css(igniter, web_module) do
    lib_web_name =
      web_module
      |> Module.split()
      |> List.last()
      |> Macro.underscore()

    content = """
    @import "tailwindcss" source(none);
    @source "../css";
    @source "../js";
    @source "../../lib/#{lib_web_name}";

    /* Add variants based on LiveView classes */
    @custom-variant phx-click-loading (.phx-click-loading&, .phx-click-loading &);
    @custom-variant phx-submit-loading (.phx-submit-loading&, .phx-submit-loading &);
    @custom-variant phx-change-loading (.phx-change-loading&, .phx-change-loading &);

    /* Make LiveView wrapper divs transparent for layout */
    [data-phx-session], [data-phx-teleported-src] { display: contents }
    """

    Igniter.create_new_file(igniter, "assets/css/phx-tailwind.css", content, on_exists: :skip)
  end
end
