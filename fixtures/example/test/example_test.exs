defmodule ExampleTest do
  use ExUnit.Case
  doctest Example

  test "runs simple Explorer example" do
    assert Explorer.Series.from_list(["apple", "mango", "banana", "orange"])
  end
end
