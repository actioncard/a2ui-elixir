defmodule A2UI.DataModelTest do
  use ExUnit.Case, async: true

  alias A2UI.DataModel

  describe "new/0" do
    test "creates empty data model" do
      model = DataModel.new()
      assert model.data == %{}
    end
  end

  describe "get/2" do
    test "root path returns entire data" do
      model = DataModel.new(%{"a" => 1, "b" => 2})
      assert {:ok, %{"a" => 1, "b" => 2}} = DataModel.get(model, "/")
    end

    test "simple key" do
      model = DataModel.new(%{"name" => "Alice"})
      assert {:ok, "Alice"} = DataModel.get(model, "/name")
    end

    test "nested path" do
      model = DataModel.new(%{"user" => %{"name" => "Alice", "age" => 30}})
      assert {:ok, "Alice"} = DataModel.get(model, "/user/name")
    end

    test "returns :error for missing path" do
      model = DataModel.new(%{"a" => 1})
      assert :error = DataModel.get(model, "/missing")
    end

    test "returns :error for missing nested path" do
      model = DataModel.new(%{"a" => %{"b" => 1}})
      assert :error = DataModel.get(model, "/a/c")
    end

    test "empty pointer returns entire data" do
      model = DataModel.new(%{"x" => 1})
      assert {:ok, %{"x" => 1}} = DataModel.get(model, "")
    end

    test "array index access" do
      model = DataModel.new(%{"items" => ["a", "b", "c"]})
      assert {:ok, "b"} = DataModel.get(model, "/items/1")
    end
  end

  describe "set/3" do
    test "set at root replaces all data" do
      model = DataModel.new(%{"old" => true})
      {:ok, model} = DataModel.set(model, "/", %{"new" => true})
      assert model.data == %{"new" => true}
    end

    test "set simple key" do
      model = DataModel.new()
      {:ok, model} = DataModel.set(model, "/name", "Alice")
      assert model.data == %{"name" => "Alice"}
    end

    test "set nested path with auto-vivification" do
      model = DataModel.new()
      {:ok, model} = DataModel.set(model, "/user/name", "Alice")
      assert model.data == %{"user" => %{"name" => "Alice"}}
    end

    test "set deeply nested path" do
      model = DataModel.new()
      {:ok, model} = DataModel.set(model, "/a/b/c/d", "deep")
      assert {:ok, "deep"} = DataModel.get(model, "/a/b/c/d")
    end

    test "set overwrites existing value" do
      model = DataModel.new(%{"name" => "Alice"})
      {:ok, model} = DataModel.set(model, "/name", "Bob")
      assert {:ok, "Bob"} = DataModel.get(model, "/name")
    end

    test "set preserves sibling keys" do
      model = DataModel.new(%{"a" => 1, "b" => 2})
      {:ok, model} = DataModel.set(model, "/a", 10)
      assert model.data == %{"a" => 10, "b" => 2}
    end
  end

  describe "delete/2" do
    test "delete key" do
      model = DataModel.new(%{"a" => 1, "b" => 2})
      {:ok, model} = DataModel.delete(model, "/a")
      assert model.data == %{"b" => 2}
    end

    test "delete nested key" do
      model = DataModel.new(%{"user" => %{"name" => "Alice", "age" => 30}})
      {:ok, model} = DataModel.delete(model, "/user/age")
      assert model.data == %{"user" => %{"name" => "Alice"}}
    end

    test "delete non-existent key is a no-op" do
      model = DataModel.new(%{"a" => 1})
      {:ok, model} = DataModel.delete(model, "/missing")
      assert model.data == %{"a" => 1}
    end

    test "delete at root clears all data" do
      model = DataModel.new(%{"a" => 1})
      {:ok, model} = DataModel.delete(model, "/")
      assert model.data == %{}
    end
  end
end
