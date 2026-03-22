defmodule A2UI.CatalogTest do
  use ExUnit.Case, async: true

  alias A2UI.{Catalog, Component}

  describe "basic_catalog_id/0" do
    test "returns the standard URL" do
      assert Catalog.basic_catalog_id() ==
               "https://a2ui.org/specification/v0_9/basic_catalog.json"
    end
  end

  describe "validate_types/2" do
    test "returns :ok for nil catalog_id" do
      components = [%Component{id: "x", type: "Anything", props: %{}}]
      assert :ok = Catalog.validate_types(components, nil)
    end

    test "returns :ok for unknown catalog_id (permissive)" do
      components = [%Component{id: "x", type: "Anything", props: %{}}]
      assert :ok = Catalog.validate_types(components, "https://example.com/unknown.json")
    end

    test "returns :ok for empty component list" do
      assert :ok = Catalog.validate_types([], Catalog.basic_catalog_id())
    end

    test "returns :ok when all types are in the basic catalog" do
      components = [
        %Component{id: "a", type: "Text", props: %{}},
        %Component{id: "b", type: "Button", props: %{}},
        %Component{id: "c", type: "Column", props: %{}}
      ]

      assert :ok = Catalog.validate_types(components, Catalog.basic_catalog_id())
    end

    test "returns error for unknown types in known catalog" do
      components = [
        %Component{id: "a", type: "Text", props: %{}},
        %Component{id: "b", type: "FancyWidget", props: %{}},
        %Component{id: "c", type: "MagicBox", props: %{}}
      ]

      assert {:error, {:invalid_component_types, types}} =
               Catalog.validate_types(components, Catalog.basic_catalog_id())

      assert Enum.sort(types) == ["FancyWidget", "MagicBox"]
    end

    test "deduplicates invalid types" do
      components = [
        %Component{id: "a", type: "Nope", props: %{}},
        %Component{id: "b", type: "Nope", props: %{}}
      ]

      assert {:error, {:invalid_component_types, ["Nope"]}} =
               Catalog.validate_types(components, Catalog.basic_catalog_id())
    end

    test "all 18 types from basic_catalog.json are valid" do
      types = ~w(
        Text Image Icon Video AudioPlayer Row Column List Card Tabs
        Modal Divider Button TextField CheckBox ChoicePicker Slider DateTimeInput
      )

      components =
        types
        |> Enum.with_index()
        |> Enum.map(fn {type, i} ->
          %Component{id: "c#{i}", type: type, props: %{}}
        end)

      assert :ok = Catalog.validate_types(components, Catalog.basic_catalog_id())
    end
  end
end
