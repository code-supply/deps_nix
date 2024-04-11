defmodule DepsNix do
  alias DepsNix.Derivation
  alias DepsNix.FetchHex

  @apps_requiring_eponymous_dir [:grpcbox, :png]

  def builders do
    [:mix, :rebar3, :make]
  end

  @spec transform(Mix.Dep.t()) :: Derivation.t()
  def transform(%Mix.Dep{} = dep) do
    case dep.opts[:lock] do
      {:hex, name, version, _hash, beam_builders, sub_deps, _, sha256} ->
        %Derivation{
          name: dep.app,
          version: version,
          builder: nix_builder(beam_builders),
          src: %FetchHex{
            pkg: name,
            version: version,
            sha256: sha256
          },
          beam_deps: beam_deps(dep.opts, sub_deps),
          unpack_phase: unpack_phase(name, version)
        }

      nil ->
        %Derivation{
          name: dep.app,
          version: dep.opts[:app_properties][:vsn],
          builder: "buildMix",
          src: nil,
          beam_deps: []
        }
    end
  end

  defp beam_deps(opts, sub_deps) do
    sub_deps
    |> Enum.map(fn {name, _version, _pm_stuff} -> name end)
    |> Enum.reject(&(&1 in optional_apps(opts)))
  end

  defp optional_apps(opts) do
    get_in(opts, [:app_properties, :optional_applications]) || []
  end

  defp unpack_phase(name, version) do
    if name in @apps_requiring_eponymous_dir do
      """
      runHook preUnpack
      unpackFile "$src"
      chmod -R u+w -- hex-source-#{name}-#{version}
      mv hex-source-#{name}-#{version} #{name}
      sourceRoot=#{name}
      runHook postUnpack
      """
    end
  end

  @spec indent(String.t() | nil) :: String.t()
  def indent(nil) do
    ""
  end

  def indent(str) do
    ("  " <> str)
    |> String.replace(~r/\n(.+)/, "\n  \\1")
  end

  defp nix_builder(builders) do
    cond do
      Enum.member?(builders, :mix) -> "buildMix"
      Enum.member?(builders, :rebar3) -> "buildRebar3"
    end
  end
end
