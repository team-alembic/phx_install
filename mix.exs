defmodule PhxInstall.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/team-alembic/phx_install"

  def project do
    [
      app: :phx_install,
      version: @version,
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Igniter-based installers for Phoenix Framework",
      package: package(),
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:igniter, "~> 0.5"},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:phx_new, "~> 1.7", only: :test, runtime: false}
    ]
  end

  defp package do
    [
      maintainers: ["Team Alembic"],
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp docs do
    [
      main: "PhxInstall",
      source_url: @source_url,
      source_ref: "v#{@version}"
    ]
  end
end
