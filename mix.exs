defmodule DepsNix.MixProject do
  use Mix.Project

  @scm_url "https://github.com/code-supply/deps_nix"

  def project do
    [
      app: :deps_nix,
      deps: deps(),
      description: "Mix task that converts Mix dependencies to Nix derivations",
      dialyzer: [plt_add_apps: [:mix]],
      elixir: "~> 1.16",
      package: package(),
      start_permanent: Mix.env() == :prod,
      version: "2.5.0",

      # Docs
      source_url: @scm_url,
      docs: [
        main: "readme",
        extras: ["README.md"]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: []
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:ex_nar, "~> 0.3.0"},
      {:mint, "~> 1.0"},
      {:stream_data, "~> 1.1", only: [:dev, :test]}
    ]
  end

  defp package do
    [
      links: %{"GitHub" => @scm_url},
      licenses: ["MIT"]
    ]
  end
end
