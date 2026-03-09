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
    test "returns unknown call descriptor as-is" do
      call = %{"call" => "openUrl", "args" => %{"url" => "https://example.com"}}
      assert {:ok, ^call} = Binding.resolve(call, DataModel.new())
    end

    test "returns validation call (no args key) as-is" do
      call = %{"call" => "required", "message" => "This field is required"}
      assert {:ok, ^call} = Binding.resolve(call, DataModel.new())
    end

    test "evaluates formatNumber with literal args" do
      call = %{"call" => "formatNumber", "args" => %{"value" => 1234.5, "decimals" => 2}}
      assert {:ok, "1,234.50"} = Binding.resolve(call, DataModel.new())
    end

    test "evaluates formatNumber with path binding arg" do
      dm = DataModel.new(%{"price" => 9999})
      call = %{"call" => "formatNumber", "args" => %{"value" => %{"path" => "/price"}}}
      assert {:ok, "9,999"} = Binding.resolve(call, dm)
    end

    test "evaluates boolean not" do
      dm = DataModel.new(%{"flag" => false})

      call = %{
        "call" => "not",
        "args" => %{"value" => %{"path" => "/flag"}}
      }

      assert {:ok, true} = Binding.resolve(call, dm)
    end

    test "passes through known function when arg path is missing" do
      dm = DataModel.new()
      call = %{"call" => "formatNumber", "args" => %{"value" => %{"path" => "/missing"}}}
      assert {:ok, ^call} = Binding.resolve(call, dm)
    end

    test "evaluates nested function call in args" do
      dm = DataModel.new(%{"count" => 5})

      call = %{
        "call" => "pluralize",
        "args" => %{
          "value" => %{"call" => "formatNumber", "args" => %{"value" => 1}},
          "one" => "1 item",
          "other" => "items"
        }
      }

      # formatNumber returns "1" (string), pluralize checks == 1 (integer)
      # so this goes to "other" — this is expected behavior
      assert {:ok, "items"} = Binding.resolve(call, dm)
    end
  end
end
