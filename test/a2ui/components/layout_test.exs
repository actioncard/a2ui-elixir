defmodule A2UI.Components.LayoutTest do
  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]
  import A2UI.Test.ComponentHelpers

  alias A2UI.Components.Renderer

  describe "Row component" do
    test "renders horizontal flex container" do
      components = %{
        "row" => make_component("row", "Row", %{"children" => ["a", "b"]}),
        "a" => make_component("a", "Text", %{"text" => "Left"}),
        "b" => make_component("b", "Text", %{"text" => "Right"})
      }

      component = components["row"]
      ctx = make_ctx(components)
      assigns = %{component: component, ctx: ctx}

      html = rendered_to_string(~H"<Renderer.component component={@component} ctx={@ctx} />")

      assert html =~ "a2ui-row"
      assert html =~ "Left"
      assert html =~ "Right"
    end

    test "applies justify and align" do
      component =
        make_component("row", "Row", %{
          "children" => [],
          "justify" => "spaceBetween",
          "align" => "center"
        })

      ctx = make_ctx(%{"row" => component})
      assigns = %{component: component, ctx: ctx}

      html = rendered_to_string(~H"<Renderer.component component={@component} ctx={@ctx} />")

      assert html =~ "a2ui-justify-space-between"
      assert html =~ "a2ui-align-center"
    end
  end

  describe "Column component" do
    test "renders vertical flex container" do
      components = %{
        "col" => make_component("col", "Column", %{"children" => ["top"]}),
        "top" => make_component("top", "Text", %{"text" => "Top"})
      }

      component = components["col"]
      ctx = make_ctx(components)
      assigns = %{component: component, ctx: ctx}

      html = rendered_to_string(~H"<Renderer.component component={@component} ctx={@ctx} />")

      assert html =~ "a2ui-column"
      assert html =~ "Top"
    end

    test "applies weight (flex-grow)" do
      component = make_component("col", "Column", %{"children" => [], "weight" => 2})
      ctx = make_ctx(%{"col" => component})
      assigns = %{component: component, ctx: ctx}

      html = rendered_to_string(~H"<Renderer.component component={@component} ctx={@ctx} />")

      assert html =~ "--a2ui-weight: 2"
    end
  end

  describe "List component" do
    test "renders vertical list with listitems" do
      components = %{
        "list" => make_component("list", "List", %{"children" => ["a", "b"]}),
        "a" => make_component("a", "Text", %{"text" => "Item 1"}),
        "b" => make_component("b", "Text", %{"text" => "Item 2"})
      }

      component = components["list"]
      ctx = make_ctx(components)
      assigns = %{component: component, ctx: ctx}

      html = rendered_to_string(~H"<Renderer.component component={@component} ctx={@ctx} />")

      assert html =~ "a2ui-list"
      assert html =~ ~s(role="list")
      assert html =~ "a2ui-list__item"
      assert html =~ ~s(role="listitem")
      assert html =~ "Item 1"
      assert html =~ "Item 2"
    end

    test "renders horizontal list" do
      component =
        make_component("list", "List", %{
          "children" => [],
          "direction" => "horizontal"
        })

      ctx = make_ctx(%{"list" => component})
      assigns = %{component: component, ctx: ctx}

      html = rendered_to_string(~H"<Renderer.component component={@component} ctx={@ctx} />")

      assert html =~ "a2ui-list--horizontal"
    end

    test "renders template children" do
      components = %{
        "list" =>
          make_component("list", "List", %{
            "children" => %{"template" => %{"componentId" => "item", "path" => "/items"}}
          }),
        "item" => make_component("item", "Text", %{"text" => %{"path" => "name"}})
      }

      ctx =
        make_ctx(components, "s1",
          data: %{
            "items" => [%{"name" => "Alice"}, %{"name" => "Bob"}, %{"name" => "Charlie"}]
          }
        )

      component = components["list"]
      assigns = %{component: component, ctx: ctx}

      html = rendered_to_string(~H"<Renderer.component component={@component} ctx={@ctx} />")

      assert html =~ "Alice"
      assert html =~ "Bob"
      assert html =~ "Charlie"

      # Each should be wrapped in a listitem
      {:ok, doc} = Floki.parse_document(html)
      [_ | _] = Floki.find(doc, ".a2ui-list__item")
    end

    test "handles empty template data" do
      components = %{
        "list" =>
          make_component("list", "List", %{
            "children" => %{"template" => %{"componentId" => "item", "path" => "/items"}}
          }),
        "item" => make_component("item", "Text", %{"text" => %{"path" => "name"}})
      }

      ctx = make_ctx(components, "s1", data: %{"items" => []})
      component = components["list"]
      assigns = %{component: component, ctx: ctx}

      html = rendered_to_string(~H"<Renderer.component component={@component} ctx={@ctx} />")

      assert html =~ "a2ui-list"
      {:ok, doc} = Floki.parse_document(html)
      assert Floki.find(doc, ".a2ui-list__item") == []
    end
  end
end
