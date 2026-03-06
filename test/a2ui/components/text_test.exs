defmodule A2UI.Components.TextTest do
  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]
  import A2UI.Test.ComponentHelpers

  alias A2UI.Components.Renderer

  describe "Text component" do
    test "renders body variant as <p> by default" do
      component = make_component("t", "Text", %{"text" => "Hello world"})
      ctx = make_ctx(%{"t" => component})
      assigns = %{component: component, ctx: ctx}

      html = rendered_to_string(~H"<Renderer.component component={@component} ctx={@ctx} />")

      assert html =~ "<p"
      assert html =~ "a2ui-text a2ui-text--body"
      assert html =~ "Hello world"
    end

    test "renders h1 variant" do
      component = make_component("t", "Text", %{"text" => "Title", "variant" => "h1"})
      ctx = make_ctx(%{"t" => component})
      assigns = %{component: component, ctx: ctx}

      html = rendered_to_string(~H"<Renderer.component component={@component} ctx={@ctx} />")

      assert html =~ "<h1"
      assert html =~ "a2ui-text--h1"
      assert html =~ "Title"
    end

    test "renders h2 through h5 variants" do
      for variant <- ~w(h2 h3 h4 h5) do
        component = make_component("t", "Text", %{"text" => "Text", "variant" => variant})
        ctx = make_ctx(%{"t" => component})
        assigns = %{component: component, ctx: ctx}

        html = rendered_to_string(~H"<Renderer.component component={@component} ctx={@ctx} />")

        assert html =~ "<#{variant}"
        assert html =~ "a2ui-text--#{variant}"
      end
    end

    test "renders caption variant as <span>" do
      component = make_component("t", "Text", %{"text" => "Note", "variant" => "caption"})
      ctx = make_ctx(%{"t" => component})
      assigns = %{component: component, ctx: ctx}

      html = rendered_to_string(~H"<Renderer.component component={@component} ctx={@ctx} />")

      assert html =~ "<span"
      assert html =~ "a2ui-text--caption"
    end

    test "resolves data-bound text" do
      component = make_component("t", "Text", %{"text" => %{"path" => "/greeting"}})
      ctx = make_ctx(%{"t" => component}, "s1", data: %{"greeting" => "Bound text"})
      assigns = %{component: component, ctx: ctx}

      html = rendered_to_string(~H"<Renderer.component component={@component} ctx={@ctx} />")

      assert html =~ "Bound text"
    end

    test "renders accessibility attributes" do
      component =
        make_component("t", "Text", %{"text" => "Accessible"},
          accessibility: %{"label" => "greeting", "role" => "heading"}
        )

      ctx = make_ctx(%{"t" => component})
      assigns = %{component: component, ctx: ctx}

      html = rendered_to_string(~H"<Renderer.component component={@component} ctx={@ctx} />")

      assert html =~ ~s(aria-label="greeting")
      assert html =~ ~s(role="heading")
    end

    test "renders empty string when text is missing" do
      component = make_component("t", "Text", %{})
      ctx = make_ctx(%{"t" => component})
      assigns = %{component: component, ctx: ctx}

      html = rendered_to_string(~H"<Renderer.component component={@component} ctx={@ctx} />")

      assert html =~ "<p"
      assert html =~ "a2ui-text"
    end
  end
end
