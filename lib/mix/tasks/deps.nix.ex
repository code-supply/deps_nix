defmodule Mix.Tasks.Deps.Nix do
  use Mix.Task

  @shortdoc "Produce nix derivations for mix dependencies"

  @impl Mix.Task
  def run(_args) do
    Mix.Project.get!()
    loaded_opts = [env: :prod, target: Mix.target()]

    shell = Mix.shell()

    Mix.Dep.Converger.converge(loaded_opts)
    |> Enum.sort_by(fn dep -> dep.app end)
    |> Enum.map(&DepsNix.transform/1)
    |> Enum.map(&to_string/1)
    |> Enum.join("\n")
    |> DepsNix.indent()
    |> DepsNix.indent()
    |> wrap()
    |> shell.info()
  end

  defp wrap(pkgs) do
    """
    { lib, beamPackages, overrides ? (x: y: { }) }:

    let
      buildRebar3 = lib.makeOverridable beamPackages.buildRebar3;
      buildMix = lib.makeOverridable beamPackages.buildMix;
      buildErlangMk = lib.makeOverridable beamPackages.buildErlangMk;

      self = packages // (overrides self packages);

      packages = with beamPackages; with self; {
    #{pkgs}  };
    in
    self
    """
    |> String.trim()
  end
end
