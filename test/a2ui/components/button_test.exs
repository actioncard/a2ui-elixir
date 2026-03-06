defmodule A2UI.Components.ButtonTest do
  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]
  import A2UI.Test.ComponentHelpers

  alias A2UI.Components.Renderer

  describe "Button component" do
    test "renders with default variant" do
      components = %{
        "btn" => make_component("btn", "Button", %{
          "child" => "label"
        }),
        "label" => make_component("label", "Text", %{"text" => "Click me"})
      }

      component = components["btn"]
      ctx = make_ctx(components)
      assigns = %{component: component, ctx: ctx}

      html = rendered_to_string(~H"<Renderer.component component={@component} ctx={@ctx} />")

      assert html =~ "<button"
      assert html =~ "a2ui-button a2ui-button--default"
      assert html =~ "Click me"
    end

    test "renders primary variant" do
      component = make_component("btn", "Button", %{"variant" => "primary"})
      ctx = make_ctx(%{"btn" => component})
      assigns = %{component: component, ctx: ctx}

      html = rendered_to_string(~H"<Renderer.component component={@component} ctx={@ctx} />")

      assert html =~ "a2ui-button--primary"
    end

    test "emits phx-click for server action" do
      component = make_component("btn", "Button", %{
        "action" => %{"event" => %{"name" => "submit", "context" => %{}}}
      })

      ctx = make_ctx(%{"btn" => component}, "surf-1")
      assigns = %{component: component, ctx: ctx}

      html = rendered_to_string(~H"<Renderer.component component={@component} ctx={@ctx} />")

      assert html =~ ~s(phx-click="a2ui_action")
      assert html =~ ~s(phx-value-surface-id="surf-1")
      assert html =~ ~s(phx-value-component-id="btn")
      assert html =~ "phx-value-action"
    end

    test "emits data attribute for local action" do
      component = make_component("btn", "Button", %{
        "action" => %{
          "functionCall" => %{"call" => "openUrl", "args" => %{"url" => "https://example.com"}}
        }
      })

      ctx = make_ctx(%{"btn" => component})
      assigns = %{component: component, ctx: ctx}

      html = rendered_to_string(~H"<Renderer.component component={@component} ctx={@ctx} />")

      assert html =~ "data-a2ui-action"
      assert html =~ "openUrl"
      refute html =~ "phx-click"
    end

    test "renders without action attributes when no action" do
      component = make_component("btn", "Button", %{})
      ctx = make_ctx(%{"btn" => component})
      assigns = %{component: component, ctx: ctx}

      html = rendered_to_string(~H"<Renderer.component component={@component} ctx={@ctx} />")

      refute html =~ "phx-click"
      refute html =~ "data-a2ui-action"
    end

    test "renders borderless variant" do
      component = make_component("btn", "Button", %{"variant" => "borderless"})
      ctx = make_ctx(%{"btn" => component})
      assigns = %{component: component, ctx: ctx}

      html = rendered_to_string(~H"<Renderer.component component={@component} ctx={@ctx} />")

      assert html =~ "a2ui-button--borderless"
    end
  end
end
