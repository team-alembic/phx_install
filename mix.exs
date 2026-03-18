defmodule PhxInstall.MixProject do
  use Mix.Project

  @version "0.1.1"
  @source_url "https://github.com/team-alembic/phx_install"

  def project do
    [
      app: :phx_install,
      version: @version,
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: [plt_add_apps: [:igniter, :mix, :rewrite, :sourceror]],
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
      {:igniter, "~> 0.7 and >= 0.7.3"},

      # dev/text
      {:credo, "~> 1.0", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:doctor, "~> 0.22", only: [:dev, :test], runtime: false},
      {:ex_check, "~> 0.16", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.34", only: [:dev, :test], runtime: false},
      {:git_ops, "~> 2.0", only: [:dev, :test], runtime: false},
      {:mix_audit, "~> 2.0", only: [:dev, :test], runtime: false},
      {:phx_new, "~> 1.7", only: :test, runtime: false}
    ]
  end

  defp package do
    [
      maintainers: ["James Harton <james.harton@alembic.com.au>"],
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => @source_url},
      source_url: @source_url
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"],
      source_url: @source_url,
      source_ref: "v#{@version}"
    ]
  end
end
