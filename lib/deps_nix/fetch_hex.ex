defmodule DepsNix.FetchHex do
  @enforce_keys [:pkg, :version, :sha256]
  defstruct [:pkg, :version, :sha256]

  defimpl String.Chars do
    def to_string(%DepsNix.FetchHex{} = h) do
      """
      fetchHex {
          pkg = "#{h.pkg}";
          version = "${version}";
          sha256 = "#{h.sha256}";
        }
      """
      |> String.trim()
    end
  end
end
