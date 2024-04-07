defmodule DepsNix.Derivation do
  @type t :: %__MODULE__{
          builder: String.t(),
          name: atom(),
          version: String.t(),
          src: DepsNix.FetchHex.t(),
          beam_deps: list(atom())
        }

  @enforce_keys [:builder, :name, :version, :src, :beam_deps]
  defstruct [:builder, :name, :version, :src, :beam_deps]
end
