defmodule Mix.Tasks.Phx.Install.Assets.Static do
  @shortdoc "Creates static placeholder files (robots.txt, favicon)"
  @moduledoc """
  Creates static placeholder files for a Phoenix application.

  This task creates:
  - `priv/static/robots.txt` - Robots exclusion file
  - `priv/static/favicon.ico` - Default favicon placeholder

  ## Usage

      mix phx.install.assets.static

  This task is typically composed by `mix phx.install.assets` rather than called directly.
  """
  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :phoenix,
      example: "mix phx.install.assets.static"
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    igniter
    |> create_robots_txt()
    |> create_favicon()
  end

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
    favicon_bytes =
      <<0, 0, 1, 0, 1, 0, 1, 1, 0, 0, 1, 0, 24, 0, 48, 0, 0, 0, 22, 0, 0, 0, 40, 0, 0, 0, 1, 0, 0,
        0, 2, 0, 0, 0, 1, 0, 24, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 255, 0, 0, 0, 0, 0>>

    Igniter.create_new_file(igniter, "priv/static/favicon.ico", favicon_bytes, on_exists: :skip)
  end
end
