defmodule DepsNix do
  alias DepsNix.Derivation
  alias DepsNix.FetchHex

  def builders do
    [:mix, :rebar3, :make]
  end

  @spec transform(Mix.Dep.t()) :: Derivation.t()
  def transform(%Mix.Dep{} = dep) do
    case dep.opts[:lock] do
      {:hex, name, version, _hash, beam_builders, sub_deps, _, sha256} ->
        %Derivation{
          name: name,
          version: version,
          builder: nix_builder(beam_builders),
          src: %FetchHex{
            pkg: name,
            version: version,
            sha256: sha256
          },
          beam_deps:
            for {name, _version, _pm_stuff} <- sub_deps do
              name
            end,
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

  def unpack_phase(:grpcbox = name, version) do
    """
    runHook preUnpack
    unpackFile "$src"
    chmod -R u+w -- hex-source-#{name}-#{version}
    mv hex-source-#{name}-#{version} #{name}
    sourceRoot=#{name}
    runHook postUnpack
    """
  end

  def unpack_phase(_, _) do
    nil
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
