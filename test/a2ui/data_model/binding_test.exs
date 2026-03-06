defmodule A2UI.DataModel.BindingTest do
  use ExUnit.Case, async: true

  alias A2UI.DataModel
  alias A2UI.DataModel.Binding

  describe "literals" do
    test "string" do
      assert {:ok, "hello"} = Binding.resolve("hello", DataModel.new())
    end

    test "number" do
      assert {:ok, 42} = Binding.resolve(42, DataModel.new())
    end

    test "float" do
      assert {:ok, 3.14} = Binding.resolve(3.14, DataModel.new())
    end

    test "boolean true" do
      assert {:ok, true} = Binding.resolve(true, DataModel.new())
    end

    test "boolean false" do
      assert {:ok, false} = Binding.resolve(false, DataModel.new())
    end

    test "nil" do
      assert {:ok, nil} = Binding.resolve(nil, DataModel.new())
    end

    test "list" do
      assert {:ok, [1, 2, 3]} = Binding.resolve([1, 2, 3], DataModel.new())
    end

    test "plain map (no path or call key)" do
      value = %{"foo" => "bar"}
      assert {:ok, ^value} = Binding.resolve(value, DataModel.new())
    end
  end

  describe "absolute path bindings" do
    test "resolves simple path" do
      dm = DataModel.new(%{"user" => %{"name" => "Alice"}})
      assert {:ok, "Alice"} = Binding.resolve(%{"path" => "/user/name"}, dm)
    end

    test "resolves root path" do
      dm = DataModel.new(%{"x" => 1})
      assert {:ok, %{"x" => 1}} = Binding.resolve(%{"path" => "/"}, dm)
    end

    test "returns :error for missing path" do
      dm = DataModel.new(%{"a" => 1})
      assert :error = Binding.resolve(%{"path" => "/missing"}, dm)
    end

    test "resolves nested path" do
      dm = DataModel.new(%{"a" => %{"b" => %{"c" => "deep"}}})
      assert {:ok, "deep"} = Binding.resolve(%{"path" => "/a/b/c"}, dm)
    end

    test "absolute path ignores scope_path" do
      dm = DataModel.new(%{"global" => "value"})
      assert {:ok, "value"} = Binding.resolve(%{"path" => "/global"}, dm, "/items/0")
    end
  end

  describe "relative path bindings" do
    test "resolves with scope_path" do
      dm = DataModel.new(%{"items" => [%{"name" => "Pizza"}]})
      assert {:ok, "Pizza"} = Binding.resolve(%{"path" => "name"}, dm, "/items/0")
    end

    test "returns :error when scope_path is nil" do
      dm = DataModel.new(%{"name" => "Alice"})
      assert :error = Binding.resolve(%{"path" => "name"}, dm)
    end

    test "returns :error when resolved path is missing" do
      dm = DataModel.new(%{"items" => [%{"name" => "Pizza"}]})
      assert :error = Binding.resolve(%{"path" => "price"}, dm, "/items/0")
    end
  end

  describe "function call descriptors" do
    test "returns call descriptor as-is" do
      call = %{"call" => "openUrl", "args" => %{"url" => "https://example.com"}}
      assert {:ok, ^call} = Binding.resolve(call, DataModel.new())
    end

    test "returns validation call as-is" do
      call = %{"call" => "required", "message" => "This field is required"}
      assert {:ok, ^call} = Binding.resolve(call, DataModel.new())
    end
  end
end
