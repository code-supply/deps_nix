# deps_nix

A Mix task that converts Mix dependencies to Nix derivations. Inspired by
[mix2nix](https://github.com/ydlr/mix2nix).

While mix2nix is a function of a `mix.lock`, this project instead uses Mix's
internals to allow you to choose packages from certain environments. It also
supports git dependencies.

## Why?

You want this if you plan to release your Elixir project using nixpkgs' [mixRelease](https://github.com/NixOS/nixpkgs/blob/master/pkgs/development/beam-modules/mix-release.nix), or have other uses for wrapping each of your Mix dependencies in derivations.

Using separate Nix derivations for each dependency:

- Avoids downloading and compiling all of your dependencies for each release, which is what happens when you use a Fixed-Output Derivation (`mixFodDeps` in `mixRelease`).
- Lets you cache compiled dependencies and reuse them when they don't change, making your release faster. This is especially important when your dependencies take a while to compile.
- Gives you loads of geek points.

## Installation

```elixir
def deps do
  [
    {:deps_nix, "~> 0.0", only: :dev}
  ]
end
```

Optional: add aliases for `deps.get` and `deps.update`. This helps to keep your
Nix dependencies in sync with what's declared in `mix.exs`:

```elixir
def project do
  [
    ...
    aliases: [
      "deps.get": ["deps.get", "deps.nix"],
      "deps.update": ["deps.update", "deps.nix"]
    ]
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
