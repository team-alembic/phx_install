defmodule Mix.Tasks.Phx.Install.Assets.Tailwind do
  @shortdoc "Sets up Tailwind CSS"
  @moduledoc """
  Sets up Tailwind CSS for a Phoenix application.

  Creates the `assets/css/app.css` entry point, then dynamically composes a
  bundler-specific runner task based on the `--bundler` flag:

  - `phx.install.assets.tailwind.esbuild` - uses the `tailwind` hex package

  To add support for a new bundler, implement a task at
  `phx.install.assets.tailwind.<bundler_name>`.

  ## Usage

      mix phx.install.assets.tailwind
      mix phx.install.assets.tailwind --bundler esbuild

  ## Options

  - `--bundler` - Which bundler is in use: "esbuild" (default)

  This task is typically composed by `mix phx.install.assets` rather than called directly.
  """
  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def info(argv, _composing_task) do
    {parsed, _, _} = OptionParser.parse(argv, strict: [bundler: :string])
    bundler = Keyword.get(parsed, :bundler, "esbuild")

    %Igniter.Mix.Task.Info{
      group: :phoenix,
      example: "mix phx.install.assets.tailwind",
      schema: [bundler: :string],
      defaults: [bundler: "esbuild"],
      composes: ["phx.install.assets.tailwind.#{bundler}"]
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    web_module = Igniter.Libs.Phoenix.web_module(igniter)

    opts = igniter.args.options
    bundler = opts[:bundler] || "esbuild"

    igniter
    |> create_app_css(web_module)
    |> Igniter.compose_task("phx.install.assets.tailwind.#{bundler}")
  end

  defp create_app_css(igniter, web_module) do
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
    """

    Igniter.create_new_file(igniter, "assets/css/app.css", content, on_exists: :skip)
  end
end
