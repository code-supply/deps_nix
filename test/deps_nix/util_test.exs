defmodule UtilTest do
  use ExUnit.Case

  test "can indent a string" do
    assert DepsNix.Util.indent("""
           hi
           there

           you
           """) == """
             hi
             there

             you
           """
  end

  test "attempting to indent nil results in an empty string" do
    assert DepsNix.Util.indent(nil) == ""
  end
end
