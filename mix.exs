defmodule A2UI.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/actioncard/a2ui-elixir"

  def project do
    [
      app: :a2ui,
      version: @version,
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      package: package(),
      docs: docs(),
      name: "A2UI",
      description:
        "Elixir renderer for the A2UI v0.9 protocol — server-driven UI over Phoenix LiveView",
      source_url: @source_url,
      homepage_url: @source_url,
      dialyzer: [plt_local_path: "priv/plts"]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:jason, "~> 1.4"},
      {:phoenix_live_view, "~> 1.0"},
      {:phoenix_html, "~> 4.0"},
      {:floki, "~> 0.36", only: :test},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:bandit, "~> 1.0", only: :dev},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end

  defp aliases do
    [
      quality: ["format --check-formatted", "credo --strict", "dialyzer"],
      "test.ci": ["test --warnings-as-errors"]
    ]
  end

  defp package do
    [
      name: "a2ui",
      maintainers: ["Action Card AB"],
      licenses: ["Apache-2.0"],
      files:
        ~w(lib .formatter.exs mix.exs README.md LICENSE CHANGELOG.md CONTRIBUTING.md SPEC.md),
      links: %{
        "GitHub" => @source_url
      }
    ]
  end

  defp docs do
    [
      main: "A2UI",
      extras: ["README.md", "CHANGELOG.md", "CONTRIBUTING.md", "SPEC.md", "LICENSE"]
    ]
  end
end
