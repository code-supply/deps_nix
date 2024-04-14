defmodule DepsNix.Run do
  alias DepsNix.Find

  defmodule Options do
    @type t :: %Options{envs: map()}
    defstruct [:envs]
  end

  @type converger :: (Keyword.t() -> list(Mix.Dep.t()))

  @spec call(converger(), Options.t()) :: String.t()
  def call(converger, opts) do
    opts
    |> convert_opts()
    |> Enum.flat_map(fn {converger_opts, permitted_package_names} ->
      all_packages_for_env = converger.(converger_opts)
      filter_packages(all_packages_for_env, permitted_package_names)
    end)
    |> Enum.sort_by(& &1.app)
    |> Enum.uniq()
    |> Enum.map(&DepsNix.transform/1)
    |> Enum.join("\n")
    |> DepsNix.indent()
    |> DepsNix.indent()
    |> wrap()
  end

  defp convert_opts(%Options{envs: envs}) do
    for {strenv, packages} <- envs do
      env = String.to_existing_atom(strenv)
      {[env: env], packages}
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

  defp filter_packages(deps, :all) do
    deps
  end

  defp filter_packages(all_packages_for_env, permitted_package_names) do
    permitted = permitted_packages(all_packages_for_env, permitted_package_names)

    sub_dependency_names =
      Enum.flat_map(permitted, fn package ->
        Find.dependency_names(all_packages_for_env, package.app)
      end)

    permitted ++
      Enum.filter(all_packages_for_env, fn dep ->
        dep.app in sub_dependency_names
      end)
  end

  defp permitted_packages(packages, permitted_names) do
    Enum.filter(packages, &("#{&1.app}" in permitted_names))
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
