defmodule DepsNix.FetchGit do
  @type t :: %__MODULE__{
          url: String.t(),
          rev: String.to(),
          hash: String.t()
        }

  @enforce_keys [:url, :rev, :hash]
  defstruct [:url, :rev, :hash]

  defimpl String.Chars do
    def to_string(%DepsNix.FetchGit{} = g) do
      """
      fetchgit {
          url = "#{g.url}";
          rev = "#{g.rev}";
          hash = "#{g.hash}";
        }
      """
      |> String.trim()
    end
  end
end
