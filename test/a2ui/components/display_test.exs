defmodule A2UI.Components.DisplayTest do
  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]
  import A2UI.Test.ComponentHelpers

  alias A2UI.Components.Renderer

  describe "Image component" do
    test "renders img tag with resolved url" do
      component =
        make_component("img", "Image", %{
          "url" => "https://example.com/photo.jpg",
          "fit" => "contain"
        })

      ctx = make_ctx(%{"img" => component})
      assigns = %{component: component, ctx: ctx}

      html = rendered_to_string(~H"<Renderer.component component={@component} ctx={@ctx} />")

      assert html =~ "<img"
      assert html =~ "a2ui-image"
      assert html =~ ~s(src="https://example.com/photo.jpg")
      assert html =~ "object-fit:contain"
    end

    test "resolves data-bound url" do
      component =
        make_component("img", "Image", %{
          "url" => %{"path" => "/photo_url"}
        })

      ctx =
        make_ctx(%{"img" => component}, "s1", data: %{"photo_url" => "https://bound.com/img.png"})

      assigns = %{component: component, ctx: ctx}

      html = rendered_to_string(~H"<Renderer.component component={@component} ctx={@ctx} />")

      assert html =~ ~s(src="https://bound.com/img.png")
    end

    test "uses accessibility label as alt" do
      component =
        make_component("img", "Image", %{"url" => "pic.jpg"},
          accessibility: %{"label" => "A sunset"}
        )

      ctx = make_ctx(%{"img" => component})
      assigns = %{component: component, ctx: ctx}

      html = rendered_to_string(~H"<Renderer.component component={@component} ctx={@ctx} />")

      assert html =~ ~s(alt="A sunset")
    end

    test "defaults to cover fit" do
      component = make_component("img", "Image", %{"url" => "pic.jpg"})
      ctx = make_ctx(%{"img" => component})
      assigns = %{component: component, ctx: ctx}

      html = rendered_to_string(~H"<Renderer.component component={@component} ctx={@ctx} />")

      assert html =~ "object-fit:cover"
    end
  end

  describe "Icon component" do
    test "renders icon with name class" do
      component = make_component("icon", "Icon", %{"name" => "search"})
      ctx = make_ctx(%{"icon" => component})
      assigns = %{component: component, ctx: ctx}

      html = rendered_to_string(~H"<Renderer.component component={@component} ctx={@ctx} />")

      assert html =~ "a2ui-icon"
      assert html =~ "a2ui-icon--search"
    end

    test "resolves data-bound icon name" do
      component = make_component("icon", "Icon", %{"name" => %{"path" => "/icon_name"}})
      ctx = make_ctx(%{"icon" => component}, "s1", data: %{"icon_name" => "star"})
      assigns = %{component: component, ctx: ctx}

      html = rendered_to_string(~H"<Renderer.component component={@component} ctx={@ctx} />")

      assert html =~ "a2ui-icon--star"
    end
  end

  describe "Divider component" do
    test "renders horizontal divider as <hr>" do
      component = make_component("div", "Divider", %{})
      ctx = make_ctx(%{"div" => component})
      assigns = %{component: component, ctx: ctx}

      html = rendered_to_string(~H"<Renderer.component component={@component} ctx={@ctx} />")

      assert html =~ "<hr"
      assert html =~ "a2ui-divider--horizontal"
    end

    test "renders explicit horizontal divider" do
      component = make_component("div", "Divider", %{"axis" => "horizontal"})
      ctx = make_ctx(%{"div" => component})
      assigns = %{component: component, ctx: ctx}

      html = rendered_to_string(~H"<Renderer.component component={@component} ctx={@ctx} />")

      assert html =~ "<hr"
    end

    test "renders vertical divider as separator div" do
      component = make_component("div", "Divider", %{"axis" => "vertical"})
      ctx = make_ctx(%{"div" => component})
      assigns = %{component: component, ctx: ctx}

      html = rendered_to_string(~H"<Renderer.component component={@component} ctx={@ctx} />")

      refute html =~ "<hr"
      assert html =~ ~s(role="separator")
      assert html =~ "a2ui-divider--vertical"
    end
  end
end
