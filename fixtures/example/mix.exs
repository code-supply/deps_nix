defmodule Example.MixProject do
  use Mix.Project

  def project do
    [
      app: :example,
      version: "0.1.0",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:bandit, github: "mtrudel/bandit", ref: "1.4.2"},
      {:deps_nix, path: "../..", only: [:dev]},
      {:eventstore, "~> 1.4"},
      {:ex_cldr, "~> 2.38"},
      {:ex_cldr_dates_times, "~> 2.17"},
      {:ex_cldr_numbers, "~> 2.33"},
      {:explorer, "~> 0.9.0"},
      {:fun_with_flags, "~> 1.12.0"},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.1.1",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:jason, "~> 1.4.1"},
      {:opentelemetry_exporter, "~> 1.7"},
      {:plug, "~> 1.13", override: true},
      {:png, "~> 0.2.1"},
      {:rustler, ">= 0.0.0", optional: true},
      {:tokenizers, "~> 0.3.0"}
    ]
  end
end
