defmodule A2UI.ComponentTreeTest do
  use ExUnit.Case, async: true

  alias A2UI.{Component, ComponentTree, DataModel}

  defp make_component(id, type, props \\ %{}) do
    %Component{id: id, type: type, props: props}
  end

  describe "root/1" do
    test "returns the root component" do
      components = %{
        "root" => make_component("root", "Column"),
        "child" => make_component("child", "Text")
      }

      assert {:ok, %Component{id: "root", type: "Column"}} = ComponentTree.root(components)
    end

    test "returns error when no root exists" do
      components = %{"header" => make_component("header", "Text")}
      assert {:error, :no_root} = ComponentTree.root(components)
    end

    test "returns error for empty map" do
      assert {:error, :no_root} = ComponentTree.root(%{})
    end
  end

  describe "child_ids/1" do
    test "single child via 'child' prop" do
      comp = make_component("card", "Card", %{"child" => "inner"})
      assert {:ids, ["inner"]} = ComponentTree.child_ids(comp)
    end

    test "children list" do
      comp = make_component("row", "Row", %{"children" => ["a", "b", "c"]})
      assert {:ids, ["a", "b", "c"]} = ComponentTree.child_ids(comp)
    end

    test "empty children list" do
      comp = make_component("row", "Row", %{"children" => []})
      assert {:ids, []} = ComponentTree.child_ids(comp)
    end

    test "template children" do
      template = %{"componentId" => "item", "path" => "/items"}
      comp = make_component("list", "List", %{"children" => %{"template" => template}})
      assert {:template, ^template} = ComponentTree.child_ids(comp)
    end

    test "no children" do
      comp = make_component("text", "Text", %{"text" => "hello"})
      assert {:none, []} = ComponentTree.child_ids(comp)
    end
  end

  describe "expand_template/3" do
    test "expands array into virtual instances" do
      dm = DataModel.new(%{"items" => ["a", "b", "c"]})
      config = %{"componentId" => "item", "path" => "/items"}

      assert {:ok, entries} = ComponentTree.expand_template(config, dm)
      assert length(entries) == 3
      assert {"item__0", 0, "/items/0"} = Enum.at(entries, 0)
      assert {"item__1", 1, "/items/1"} = Enum.at(entries, 1)
      assert {"item__2", 2, "/items/2"} = Enum.at(entries, 2)
    end

    test "expands with base_path" do
      dm = DataModel.new(%{"data" => %{"list" => [1, 2]}})
      config = %{"componentId" => "row", "path" => "/list"}

      assert {:ok, entries} = ComponentTree.expand_template(config, dm, "/data")
      assert {"row__0", 0, "/data/list/0"} = Enum.at(entries, 0)
      assert {"row__1", 1, "/data/list/1"} = Enum.at(entries, 1)
    end

    test "empty array returns empty list" do
      dm = DataModel.new(%{"items" => []})
      config = %{"componentId" => "item", "path" => "/items"}

      assert {:ok, []} = ComponentTree.expand_template(config, dm)
    end

    test "returns error when path not found" do
      dm = DataModel.new(%{})
      config = %{"componentId" => "item", "path" => "/missing"}

      assert {:error, :path_not_found} = ComponentTree.expand_template(config, dm)
    end

    test "returns error when path points to non-array" do
      dm = DataModel.new(%{"items" => "not an array"})
      config = %{"componentId" => "item", "path" => "/items"}

      assert {:error, :not_an_array} = ComponentTree.expand_template(config, dm)
    end

    test "returns error when path points to a map" do
      dm = DataModel.new(%{"items" => %{"a" => 1}})
      config = %{"componentId" => "item", "path" => "/items"}

      assert {:error, :not_an_array} = ComponentTree.expand_template(config, dm)
    end
  end

  describe "validate_references/1" do
    test "valid references" do
      components = %{
        "root" => make_component("root", "Column", %{"children" => ["a", "b"]}),
        "a" => make_component("a", "Text"),
        "b" => make_component("b", "Text")
      }

      assert :ok = ComponentTree.validate_references(components)
    end

    test "valid with single child" do
      components = %{
        "card" => make_component("card", "Card", %{"child" => "inner"}),
        "inner" => make_component("inner", "Text")
      }

      assert :ok = ComponentTree.validate_references(components)
    end

    test "missing child reference" do
      components = %{
        "root" => make_component("root", "Column", %{"children" => ["a", "missing"]}),
        "a" => make_component("a", "Text")
      }

      assert {:error, {:missing_refs, refs}} = ComponentTree.validate_references(components)
      assert {"root", "missing"} in refs
    end

    test "no children is valid" do
      components = %{
        "text" => make_component("text", "Text", %{"text" => "hello"})
      }

      assert :ok = ComponentTree.validate_references(components)
    end

    test "template children are not validated as IDs" do
      template = %{"componentId" => "item-tpl", "path" => "/items"}

      components = %{
        "list" => make_component("list", "List", %{"children" => %{"template" => template}})
      }

      # Template componentId references are not validated here —
      # they're resolved at render time via expand_template
      assert :ok = ComponentTree.validate_references(components)
    end
  end
end
