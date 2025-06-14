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
      {:brod, "~> 3.16"},
      {:deps_nix, path: "../..", only: [:dev]},
      {:eventstore, "~> 1.4"},
      {:ex_secp256k1, "~> 0.7.3"},
      {:ex_cldr, "~> 2.38"},
      {:ex_cldr_dates_times, "~> 2.17"},
      {:ex_cldr_numbers, "~> 2.33"},
      {:ex_keccak, "~> 0.7.6"},
      {:explorer, "~> 0.10.1"},
      {:fun_with_flags, "~> 1.12.0"},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.1.1",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:image, "~> 0.37"},
      {:jason, "~> 1.4.1"},
      {:opentelemetry_exporter, "~> 1.7"},
      {:plug, "~> 1.13", override: true},
      {:png, "~> 0.2.1"},
      {:redix, "~> 1.0"},
      {:rustler, ">= 0.0.0", optional: true},
      {:tokenizers, "~> 0.3.0"},
      {:unicode_string, "~> 1.7"}
    ]
  end
end
