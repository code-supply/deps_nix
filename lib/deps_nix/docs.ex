defmodule DepsNix.Docs do
  @spec markdown(String.t()) :: String.t()
  def markdown(command) do
    """
    Creates Nix derivations for Mix dependencies.

    When run without arguments, generates `deps.nix` in the current directory, but
    only for `:prod` dependencies.

    The resulting file contains a Nix function that can be called with an empty
    attribute set:

    ```
    pkgs.callPackages ./deps.nix { }
    ```

    That attribute set can optionally include overrides, which look like Nix
    overlays:

    ```
    pkgs.callPackages ./deps.nix {
      overrides = (
        final: prev: {
          some_mix_dep = prev.some_mix_dep.override {
            mixEnv = "dev";
          };
        }
      );
    }
    ```

    ## Options

      * `--env ENV[=PKG,PKG]` - include an environment's dependencies, optionally
        limited to the given packages. Repeatable. Defaults to `--env prod`.
      * `--output PATH` - where to write the Nix expression. Defaults to
        `deps.nix`.
      * `--include-paths` - include `:path` dependencies.
      * `--no-app-config` - omit `appConfigPath` from `buildMix` derivations.
      * `--app-config-path PATH` - set `appConfigPath` for all derivations.
      * `--help` - show this documentation.
      * `--version` - show the deps_nix version.

    ## Example with all options

    This command creates derivations for everything in `:prod`, and only `ex_doc`
    and `credo` in `:dev`. It will include `:path` dependencies (this option is
    useful for repos with multiple Mix projects). It outputs the Nix expression
    to `nix/deps.nix`. It specifies `appConfigPath` to be `./my-app/config` for
    all nix dependency derivations.

    ```
    #{command} --include-paths --env prod --env dev=ex_doc,credo --output nix/deps.nix --app-config-path ./my-app/config
    ```

    ## Application config

    By default, every `buildMix` derivation is given an `appConfigPath` pointing
    at your application's `config` directory, so that dependencies see your
    compile-time configuration. This means a change to any config file
    invalidates every dependency and forces a recompile.

    Pass `--no-app-config` to omit `appConfigPath` entirely. Dependencies then
    build with an empty config and are no longer rebuilt when your config
    changes. Individual dependencies that need compile-time config can be given
    one back through the `overrides` argument of the generated file:

    ```
    some_dep = prev.some_dep.override { appConfigPath = ./config; };
    ```

    ## Git dependencies

    `deps_nix` supports git dependencies.

    For open-source GitHub dependencies, `pkgs.fetchFromGitHub` is used. Hashes
    are prefetched using [Mint](https://hexdocs.pm/mint) and hashed using `nix hash path`.

    `builtins.fetchGit` is used for non-GitHub projects, which doesn't require
    any prefetching and relies on the git SHA as a unique identifier. However, it
    suffers from [several disadvantages](https://discourse.nixos.org/t/fetchgit-vs-fetchgit/23325).
    """
  end
end
