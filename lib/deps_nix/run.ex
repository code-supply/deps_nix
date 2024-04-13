defmodule DepsNix.Run do
  def call(converger, opts) do
    converger.(opts)
    |> Enum.sort_by(fn dep -> dep.app end)
    |> Enum.map(&DepsNix.transform/1)
    |> Enum.map(&to_string/1)
    |> Enum.join("\n")
    |> DepsNix.indent()
    |> DepsNix.indent()
    |> wrap()
  end

  def parse_args(args) do
    {opts, _, _} = OptionParser.parse(args, strict: [env: :string])
    [env: get_env(opts)]
  end

  defp get_env(opts) do
    opts
    |> Keyword.get(:env, "prod")
    |> String.to_existing_atom()
  rescue
    ArgumentError -> :prod
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
