# deps_nix

A Mix task that converts Mix dependencies to Nix derivations. Inspired by mix2nix.

## Installation

```elixir
def deps do
  [
    {:deps_nix, "~> 0.1.0"}
  ]
end
```

Docs can be found at <https://hexdocs.pm/deps_nix>.

# Usage

```shell
mix deps.nix
```

By default, this will generate a deps.nix file in the current directory, using only the `:prod` dependencies for your project.

See mix help deps.nix, or the documentation for more options.
