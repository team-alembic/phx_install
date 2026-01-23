defmodule PhxInstall do
  @moduledoc """
  Igniter-based installers for Phoenix Framework.

  This library provides composable Mix tasks that can install Phoenix
  into new or existing Elixir projects using Igniter's AST manipulation.

  ## Entry Points

  - `mix igniter.install phx_install` - Interactive installer with prompts
  - `mix phx.install` - Main orchestrator with flags

  ## Individual Installers

  - `mix phx.install.core` - Base app structure, config, deps
  - `mix phx.install.endpoint` - Phoenix.Endpoint, telemetry, PubSub
  - `mix phx.install.router` - Router with pipelines
  - `mix phx.install.live` - LiveView support (optional)
  - `mix phx.install.assets` - esbuild/tailwind (optional)
  - `mix phx.install.gettext` - Internationalization (optional)
  - `mix phx.install.dashboard` - LiveDashboard (optional)
  """

  @version Mix.Project.config()[:version]

  @doc """
  Returns the current version of PhxInstall.
  """
  def version, do: @version

  @doc """
  Generates a random string suitable for use as a signing salt or secret.
  """
  def random_string(length \\ 32) do
    length
    |> :crypto.strong_rand_bytes()
    |> Base.encode64()
    |> binary_part(0, length)
  end
end
