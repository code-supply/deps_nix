defmodule DepsNix do
  alias DepsNix.Derivation
  alias DepsNix.FetchHex

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
            end
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

  @spec load(Derivation.t(), String.t()) :: String.t()
  def load(%Derivation{} = drv, acc) do
    """
    #{acc}
    #{drv.name} = #{drv.builder} rec {
      name = "#{drv.name}";
      version = "#{drv.version}";

      src = #{drv.src};

      beamDeps = #{format_beam_deps(drv.beam_deps)};
    };
    """
    |> String.trim_leading()
  end

  @spec indent(String.t()) :: String.t()
  def indent(str) do
    ("  " <> str)
    |> String.replace(~r/\n(.+)/, "\n  \\1")
  end

  defp nix_builder([:rebar3]) do
    "buildRebar3"
  end

  defp nix_builder([:mix]) do
    "buildMix"
  end

  defp format_beam_deps([]) do
    "[ ]"
  end

  defp format_beam_deps(deps) do
    "[ #{Enum.join(deps, " ")} ]"
  end
end
