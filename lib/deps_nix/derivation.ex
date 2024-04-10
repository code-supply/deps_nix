defmodule DepsNix.Derivation do
  @type t :: %__MODULE__{
          builder: String.t(),
          name: atom(),
          version: String.t(),
          src: DepsNix.FetchHex.t(),
          beam_deps: list(atom()),
          unpack_phase: String.t() | nil
        }

  @enforce_keys [:builder, :name, :version, :src, :beam_deps]
  defstruct [:builder, :name, :version, :src, :beam_deps, :unpack_phase]

  defimpl String.Chars do
    def to_string(drv) do
      """
      #{drv.name} = #{drv.builder} rec {
        name = "#{drv.name}";
        version = "#{drv.version}";

        src = #{drv.src};

        beamDeps = #{format_beam_deps(drv.beam_deps)};
      #{unpack_phase(drv.unpack_phase)}};
      """
    end

    defp unpack_phase(nil) do
    end

    defp unpack_phase(script) do
      "\n" <>
        DepsNix.indent("""
        unpackPhase = ''
        #{script |> String.trim_trailing() |> DepsNix.indent()}
        '';
        """)
    end

    defp format_beam_deps([]) do
      "[ ]"
    end

    defp format_beam_deps(deps) do
      "[ #{Enum.join(deps, " ")} ]"
    end
  end
end
