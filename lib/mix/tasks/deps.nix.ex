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
    overrides = (final: prev: with pkgs.beamPackages; {
      some_mix_dep = prev.some_mix_dep.override {
        mixEnv = "dev";
      }
    };
  }
  ```

  ## Example with all options

  This command creates derivations for everything in `:prod`, and only `ex_doc`
  and `credo` in `:dev`. It outputs the Nix expression to `nix/deps.nix`.

  ```
  mix deps.nix --env prod --env dev=ex_doc,credo --output nix/deps.nix
  ```

  ## Git dependencies

  `deps_nix` supports git dependencies.

  If you have declared git dependencies in your `mix.exs`, you'll need to make
  `nix-prefetch-scripts` available in the `PATH` in order to resolve their
  hashes.
  """

  @shortdoc "Produce nix derivations for mix dependencies"

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    Mix.Project.get!()

    {path, output} =
      DepsNix.Run.call(
        DepsNix.Run.parse_args(args),
        &Mix.Dep.Converger.converge/1,
        choose_prefetcher(System.get_env("EMPTY_GIT_HASHES"))
      )

    File.write!(path, output)
  end

  defp choose_prefetcher(nil) do
    &prefetcher/2
  end

  defp choose_prefetcher(_) do
    fn _url, _rev -> "{}" end
  end

  defp prefetcher(url, rev) do
    {output, 0} = System.cmd("nix-prefetch-git", ["--quiet", url, rev])
    output
  rescue
    e in ErlangError ->
      Mix.shell().error(
        "Git dependency encountered: #{url}\nHave you installed nix-prefetch-scripts?"
      )

      reraise e, __STACKTRACE__
  end
end
