defmodule A2UI.DataModel.JsonPointerTest do
  use ExUnit.Case, async: true

  alias A2UI.DataModel.JsonPointer

  describe "parse/1" do
    test "empty string returns empty list" do
      assert {:ok, []} = JsonPointer.parse("")
    end

    test "root pointer returns list with empty string" do
      assert {:ok, [""]} = JsonPointer.parse("/")
    end

    test "simple path" do
      assert {:ok, ["foo", "bar", "0"]} = JsonPointer.parse("/foo/bar/0")
    end

    test "single segment" do
      assert {:ok, ["foo"]} = JsonPointer.parse("/foo")
    end

    test "unescapes ~1 to /" do
      assert {:ok, ["a/b"]} = JsonPointer.parse("/a~1b")
    end

    test "unescapes ~0 to ~" do
      assert {:ok, ["a~b"]} = JsonPointer.parse("/a~0b")
    end

    test "combined escaping" do
      assert {:ok, ["a/b", "c~d"]} = JsonPointer.parse("/a~1b/c~0d")
    end

    test "order matters: ~01 unescapes to ~1, not to /" do
      assert {:ok, ["~1"]} = JsonPointer.parse("/~01")
    end

    test "invalid pointer without leading slash" do
      assert {:error, _} = JsonPointer.parse("foo/bar")
    end
  end

  describe "to_string/1" do
    test "empty list returns empty string" do
      assert "" = JsonPointer.to_string([])
    end

    test "simple tokens" do
      assert "/foo/bar" = JsonPointer.to_string(["foo", "bar"])
    end

    test "escapes ~ to ~0" do
      assert "/a~0b" = JsonPointer.to_string(["a~b"])
    end

    test "escapes / to ~1" do
      assert "/a~1b" = JsonPointer.to_string(["a/b"])
    end

    test "roundtrip" do
      path = "/foo/a~1b/c~0d/0"
      {:ok, tokens} = JsonPointer.parse(path)
      assert path == JsonPointer.to_string(tokens)
    end
  end
end
