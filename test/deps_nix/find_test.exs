defmodule DepsNix.FindTest do
  use ExUnit.Case

  alias DepsNix.Find

  test "can find all dependencies of a package" do
    packages = [
      %Mix.Dep{
        app: :ex_doc,
        top_level: true,
        deps: [
          %Mix.Dep{app: :makeup_elixir, top_level: false, deps: []}
        ]
      },
      %Mix.Dep{
        app: :makeup_elixir,
        top_level: false,
        deps: [
          %Mix.Dep{app: :makeup, top_level: false, deps: []}
        ]
      },
      %Mix.Dep{app: :makeup, top_level: false, deps: []}
    ]

    assert Find.dependency_names(packages, :ex_doc) == [:makeup_elixir, :makeup]
  end
end
