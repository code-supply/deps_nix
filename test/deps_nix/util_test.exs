defmodule UtilTest do
  use ExUnit.Case, async: true

  alias DepsNix.Util

  test "can indent a string" do
    assert Util.indent("""
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
    assert Util.indent(nil) == ""
  end

  test "can indent from a given line" do
    assert Util.indent(
             """
             hi
             there

             you
             """,
             from: 1
           ) == """
           hi
             there

             you
           """

    assert DepsNix.Util.indent(
             """
             hi
             there

             you
             """,
             from: 2
           ) == """
           hi
           there

             you
           """
  end
end
