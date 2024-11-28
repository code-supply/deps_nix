defmodule Mix.Tasks.Deps.Nix do
  @moduledoc """
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

  ## Example with all options

  This command creates derivations for everything in `:prod`, and only `ex_doc`
  and `credo` in `:dev`. It will include `:path` dependencies (this option is
  useful for repos with multiple Mix projects). It outputs the Nix expression
  to `nix/deps.nix`.

  ```
  mix deps.nix --include-paths --env prod --env dev=ex_doc,credo --output nix/deps.nix
  ```

  ## Git dependencies

  `deps_nix` supports git dependencies.

  `builtins.fetchGit` is used, which doesn't require any prefetching and relies
  on the git SHA as a unique identifier.
  """

  @shortdoc "Produce nix derivations for mix dependencies"

  use Mix.Task

  @requirements ["app.config"]
  @impl Mix.Task
  def run(args) do
    {:ok, _started_apps} = Application.ensure_all_started(:mint)

    Mix.Project.get!()

    {path, output} =
      DepsNix.run(
        DepsNix.parse_args(args),
        &Mix.Dep.Converger.converge/1
      )

    File.write!(path, output)
  end
end
