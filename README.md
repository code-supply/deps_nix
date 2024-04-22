# deps_nix

A Mix task that converts Mix dependencies to Nix derivations. Inspired by
[mix2nix](https://github.com/ydlr/mix2nix).

While mix2nix is a function of a `mix.lock`, this project instead uses Mix's
internals to allow you to choose packages from certain environments. It also
supports git dependencies.

## Installation

```elixir
def deps do
  [
    {:deps_nix, "~> 0.2.0"}
  ]
end
```

Docs can be found at <https://hexdocs.pm/deps_nix>.

## Usage

```shell
mix deps.nix
```

By default, this will generate a `deps.nix` file in the current directory,
using only the `:prod` dependencies for your project.

See `mix help deps.nix` for more options.
