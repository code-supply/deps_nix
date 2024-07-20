defmodule DepsNix.FetchGit do
  @type t :: %__MODULE__{
          url: String.t(),
          rev: String.t()
        }

  @enforce_keys [:url, :rev]
  defstruct [:url, :rev]

  defimpl String.Chars do
    def to_string(%DepsNix.FetchGit{} = g) do
      """
      builtins.fetchGit {
        url = "#{g.url}";
        rev = "#{g.rev}";
        allRefs = true;
      };\
      """
    end
  end
end
