defmodule Mix.Tasks.Phx.Install.Assets.LiveReload do
  @shortdoc "Configures live reload for development"
  @moduledoc """
  Configures Phoenix live reload for development.

  This task sets up the `live_reload` configuration in `runtime.exs`, guarded
  by `config_env() == :dev`, which watches for file changes and triggers
  browser reloads during development.

  ## Usage

      mix phx.install.assets.live_reload

  This task is typically composed by `mix phx.install.assets` rather than called directly.
  """
  use Igniter.Mix.Task

  alias Igniter.Code.Common
  alias Sourceror.Zipper

  @impl Igniter.Mix.Task
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :phoenix,
      example: "mix phx.install.assets.live_reload"
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    app_name = Igniter.Project.Application.app_name(igniter)
    web_module = Igniter.Libs.Phoenix.web_module(igniter)
    endpoint_module = Module.concat(web_module, Endpoint)

    dev_block = dev_block(app_name, endpoint_module)

    Igniter.create_or_update_elixir_file(
      igniter,
      "config/runtime.exs",
      "import Config\n\n" <> dev_block,
      fn zipper ->
        if configured?(zipper) do
          {:ok, zipper}
        else
          {:ok, insert_dev_block(zipper, dev_block)}
        end
      end
    )
  end

  defp dev_block(app_name, endpoint_module) do
    """
    # Reload browser tabs when matching files change.
    if config_env() == :dev do
      config #{inspect(app_name)}, #{inspect(endpoint_module)},
        live_reload: [
          web_console_logger: true,
          patterns: [
            ~r"priv/static/(?!uploads/).*\\.(js|css|png|jpeg|jpg|gif|svg)$",
            ~r"lib/.*_web/router\\.ex$",
            ~r"lib/.*_web/(controllers|live|components)/.*\\.(ex|heex)$"
          ]
        ]
    end
    """
  end

  # Keeps the task idempotent: re-running it must not append a second block.
  defp configured?(zipper) do
    zipper
    |> Zipper.topmost_root()
    |> Sourceror.to_string()
    |> String.contains?("live_reload:")
  end

  # `phx.new` places the dev block ahead of the prod one, so match that
  # ordering when the prod block is present and fall back to appending.
  defp insert_dev_block(zipper, dev_block) do
    code = separated(dev_block)

    case Common.move_to(zipper, &prod_env_block?/1) do
      {:ok, prod_block} -> Common.add_code(prod_block, code, placement: :before)
      :error -> Common.add_code(zipper, code, placement: :after)
    end
  end

  # `:newlines` tells Sourceror how many line breaks precede the node, which
  # keeps a blank line between this block and the config above it.
  defp separated(code) do
    {call, meta, args} = Sourceror.parse_string!(code)
    {call, Keyword.put(meta, :newlines, 2), args}
  end

  defp prod_env_block?(%Zipper{node: {:if, _, [condition | _]}}) do
    condition
    |> Sourceror.to_string()
    |> String.contains?("config_env() == :prod")
  end

  defp prod_env_block?(_zipper), do: false
end
