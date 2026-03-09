defmodule A2UI.Components.ContainerTest do
  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]
  import A2UI.Test.ComponentHelpers

  alias A2UI.Components.Renderer

  describe "Card component" do
    test "renders card with child" do
      components = %{
        "card" => make_component("card", "Card", %{"child" => "inner"}),
        "inner" => make_component("inner", "Text", %{"text" => "Card content"})
      }

      component = components["card"]
      ctx = make_ctx(components)
      assigns = %{component: component, ctx: ctx}

      html = rendered_to_string(~H"<Renderer.component component={@component} ctx={@ctx} />")

      assert html =~ "a2ui-card"
      assert html =~ "Card content"
    end

    test "renders empty card when no child" do
      component = make_component("card", "Card", %{})
      ctx = make_ctx(%{"card" => component})
      assigns = %{component: component, ctx: ctx}

      html = rendered_to_string(~H"<Renderer.component component={@component} ctx={@ctx} />")

      assert html =~ "a2ui-card"
    end

    test "renders accessibility attributes" do
      component = make_component("card", "Card", %{}, accessibility: %{"label" => "Info card"})

      ctx = make_ctx(%{"card" => component})
      assigns = %{component: component, ctx: ctx}

      html = rendered_to_string(~H"<Renderer.component component={@component} ctx={@ctx} />")

      assert html =~ ~s(aria-label="Info card")
    end
  end

  describe "Tabs component" do
    test "renders tab bar and panels" do
      components = %{
        "tabs" =>
          make_component("tabs", "Tabs", %{
            "tabItems" => [
              %{"title" => "Info", "child" => "panel1"},
              %{"title" => "Settings", "child" => "panel2"}
            ]
          }),
        "panel1" => make_component("panel1", "Text", %{"text" => "Info content"}),
        "panel2" => make_component("panel2", "Text", %{"text" => "Settings content"})
      }

      component = components["tabs"]
      ctx = make_ctx(components)
      assigns = %{component: component, ctx: ctx}

      html = rendered_to_string(~H"<Renderer.component component={@component} ctx={@ctx} />")

      assert html =~ "a2ui-tabs"
      assert html =~ ~s(role="tablist")
      assert html =~ ~s(role="tab")
      assert html =~ ~s(role="tabpanel")
      assert html =~ "Info"
      assert html =~ "Settings"
      assert html =~ "Info content"
      assert html =~ "Settings content"
    end

    test "first tab is active, rest hidden" do
      components = %{
        "tabs" =>
          make_component("tabs", "Tabs", %{
            "tabItems" => [
              %{"title" => "Tab 1", "child" => "p1"},
              %{"title" => "Tab 2", "child" => "p2"}
            ]
          }),
        "p1" => make_component("p1", "Text", %{"text" => "First"}),
        "p2" => make_component("p2", "Text", %{"text" => "Second"})
      }

      component = components["tabs"]
      ctx = make_ctx(components)
      assigns = %{component: component, ctx: ctx}

      html = rendered_to_string(~H"<Renderer.component component={@component} ctx={@ctx} />")

      # First tab button should be active
      assert html =~ "a2ui-tabs__tab--active"

      # Second panel should be hidden
      assert html =~ "a2ui-tabs__panel--hidden"

      # First panel should be visible (active)
      assert html =~ "a2ui-tabs__panel--active"
    end
  end

  describe "Modal component" do
    test "renders entry point and hidden overlay" do
      components = %{
        "modal" =>
          make_component("modal", "Modal", %{
            "entryPointChild" => "trigger",
            "contentChild" => "dialog"
          }),
        "trigger" =>
          make_component("trigger", "Button", %{
            "child" => "trigger-text"
          }),
        "trigger-text" => make_component("trigger-text", "Text", %{"text" => "Open"}),
        "dialog" => make_component("dialog", "Text", %{"text" => "Modal content"})
      }

      component = components["modal"]
      ctx = make_ctx(components)
      assigns = %{component: component, ctx: ctx}

      html = rendered_to_string(~H"<Renderer.component component={@component} ctx={@ctx} />")

      assert html =~ "a2ui-modal"
      assert html =~ "a2ui-modal__entry"
      assert html =~ "Open"
      assert html =~ "a2ui-modal__overlay"
      assert html =~ "a2ui-modal__overlay--hidden"
      assert html =~ ~s(role="dialog")
      assert html =~ "a2ui-modal__content"
      assert html =~ "Modal content"
    end

    test "renders without entry point" do
      components = %{
        "modal" =>
          make_component("modal", "Modal", %{
            "contentChild" => "content"
          }),
        "content" => make_component("content", "Text", %{"text" => "Hidden"})
      }

      component = components["modal"]
      ctx = make_ctx(components)
      assigns = %{component: component, ctx: ctx}

      html = rendered_to_string(~H"<Renderer.component component={@component} ctx={@ctx} />")

      assert html =~ "a2ui-modal"
      assert html =~ "Hidden"
    end

    test "renders without content" do
      components = %{
        "modal" =>
          make_component("modal", "Modal", %{
            "entryPointChild" => "trigger"
          }),
        "trigger" => make_component("trigger", "Text", %{"text" => "Trigger"})
      }

      component = components["modal"]
      ctx = make_ctx(components)
      assigns = %{component: component, ctx: ctx}

      html = rendered_to_string(~H"<Renderer.component component={@component} ctx={@ctx} />")

      assert html =~ "Trigger"
      refute html =~ "a2ui-modal__overlay"
    end
  end
end
