defmodule DepsNix.FetchHex do
  @type t :: %__MODULE__{
          pkg: atom(),
          version: String.t(),
          sha256: String.t()
        }

  @enforce_keys [:pkg, :version, :sha256]
  defstruct [:pkg, :version, :sha256]

  defimpl String.Chars do
    def to_string(%DepsNix.FetchHex{} = h) do
      """
      fetchHex {
        inherit version;
        pkg = "#{h.pkg}";
        sha256 = "#{h.sha256}";
      };\
      """
    end
  end
end
