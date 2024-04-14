defmodule DepsNix.Run do
  defmodule Options do
    @type t :: %Options{envs: map()}
    defstruct [:envs]
  end

  @type converger :: (Keyword.t() -> list(Mix.Dep.t()))

  @spec call(converger(), Options.t()) :: String.t()
  def call(converger, opts) do
    for converger_opts <- convert_opts(opts), reduce: [] do
      acc ->
        acc ++ converger.(converger_opts)
    end
    |> Enum.sort_by(fn dep -> dep.app end)
    |> Enum.map(&DepsNix.transform/1)
    |> Enum.map(&to_string/1)
    |> Enum.join("\n")
    |> DepsNix.indent()
    |> DepsNix.indent()
    |> wrap()
  end

  defp convert_opts(%Options{envs: envs}) do
    for {strenv, _packages} <- envs do
      env = String.to_existing_atom(strenv)
      [env: env]
    end
  end

  @spec parse_args(list()) :: Options.t()
  def parse_args(args) do
    args
    |> OptionParser.parse(strict: [env: [:string, :keep]])
    |> to_opts()
  end

  @spec to_opts({list(), any(), any()}) :: Options.t()
  defp to_opts({[], _, _}) do
    %Options{envs: %{"prod" => :all}}
  end

  defp to_opts({opts, _, _}) do
    %Options{
      envs:
        for {:env, env} <- opts, into: %{} do
          case String.split(env, "=", parts: 2) do
            [env] ->
              {env, :all}

            [env, ""] ->
              {env, []}

            [env, packages] ->
              {env, String.split(packages, ",")}
          end
        end
    }
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
