defmodule DepsNix.PackagesTest do
  use ExUnit.Case, async: true

  alias DepsNix.Packages

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

    assert Packages.dependency_names(packages, :ex_doc) == [:makeup_elixir, :makeup]
  end
end
