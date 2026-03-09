defmodule A2UI.Components.RendererTest do
  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]
  import A2UI.Test.ComponentHelpers

  alias A2UI.Components.Renderer

  describe "surface/1" do
    test "renders a surface with root component" do
      components = %{
        "root" => make_component("root", "Text", %{"text" => "Hello"})
      }

      surface = make_surface("s1", components)
      assigns = %{surface: surface}

      html = rendered_to_string(~H"<Renderer.surface surface={@surface} />")

      assert html =~ ~s(data-surface-id="s1")
      assert html =~ "a2ui-surface"
      assert html =~ "Hello"
    end

    test "applies theme CSS variables as inline style" do
      components = %{
        "root" => make_component("root", "Text", %{"text" => "Themed"})
      }

      surface = make_surface("s1", components, theme: %{primary_color: "#ff0000"})
      assigns = %{surface: surface}

      html = rendered_to_string(~H"<Renderer.surface surface={@surface} />")

      assert html =~ ~s(style="--a2ui-primary:#ff0000")
      assert html =~ "Themed"
    end

    test "renders empty div when no root" do
      surface = make_surface("s1", %{})
      assigns = %{surface: surface}

      html = rendered_to_string(~H"<Renderer.surface surface={@surface} />")

      assert html =~ "a2ui-surface--empty"
    end

    test "full restaurant booking surface" do
      components = %{
        "root" =>
          make_component("root", "Column", %{
            "children" => ["header", "form-card"],
            "align" => "stretch"
          }),
        "header" =>
          make_component("header", "Text", %{
            "text" => "Book Your Table",
            "variant" => "h1"
          }),
        "form-card" => make_component("form-card", "Card", %{"child" => "form-col"}),
        "form-col" =>
          make_component("form-col", "Column", %{
            "children" => ["date-input", "submit-row"]
          }),
        "date-input" =>
          make_component("date-input", "DateTimeInput", %{
            "label" => "Select Date",
            "value" => %{"path" => "/reservation/date"},
            "enableDate" => true
          }),
        "submit-row" =>
          make_component("submit-row", "Row", %{
            "children" => ["submit-btn"],
            "justify" => "end"
          }),
        "submit-text" => make_component("submit-text", "Text", %{"text" => "Confirm"}),
        "submit-btn" =>
          make_component("submit-btn", "Button", %{
            "child" => "submit-text",
            "variant" => "primary",
            "action" => %{"event" => %{"name" => "confirm_booking"}}
          })
      }

      surface =
        make_surface("main", components,
          data: %{
            "reservation" => %{"date" => "2025-12-15"}
          }
        )

      assigns = %{surface: surface}
      html = rendered_to_string(~H"<Renderer.surface surface={@surface} />")

      # Structure checks
      assert html =~ "a2ui-column"
      assert html =~ "a2ui-card"
      assert html =~ "Book Your Table"
      assert html =~ "Select Date"
      assert html =~ ~s(value="2025-12-15")
      assert html =~ "a2ui-button--primary"
      assert html =~ "Confirm"
      assert html =~ "phx-click"
      assert html =~ "a2ui_action"
    end
  end

  describe "component/1" do
    test "renders unknown component type as placeholder" do
      component = make_component("x", "VideoPlayer", %{})
      ctx = make_ctx(%{"x" => component})
      assigns = %{component: component, ctx: ctx}

      html = rendered_to_string(~H"<Renderer.component component={@component} ctx={@ctx} />")

      assert html =~ "a2ui-unknown"
      assert html =~ "VideoPlayer"
    end
  end

  describe "render_children/1" do
    test "renders static children" do
      components = %{
        "parent" => make_component("parent", "Row", %{"children" => ["a", "b"]}),
        "a" => make_component("a", "Text", %{"text" => "First"}),
        "b" => make_component("b", "Text", %{"text" => "Second"})
      }

      parent = components["parent"]
      ctx = make_ctx(components)
      assigns = %{component: parent, ctx: ctx}

      html =
        rendered_to_string(~H"<Renderer.render_children component={@component} ctx={@ctx} />")

      assert html =~ "First"
      assert html =~ "Second"
    end

    test "renders template children with data binding" do
      components = %{
        "list" =>
          make_component("list", "Column", %{
            "children" => %{"template" => %{"componentId" => "item", "path" => "/items"}}
          }),
        "item" => make_component("item", "Text", %{"text" => %{"path" => "name"}})
      }

      ctx =
        make_ctx(components, "s1",
          data: %{
            "items" => [%{"name" => "Alice"}, %{"name" => "Bob"}]
          }
        )

      parent = components["list"]
      assigns = %{component: parent, ctx: ctx}

      html =
        rendered_to_string(~H"<Renderer.render_children component={@component} ctx={@ctx} />")

      assert html =~ "Alice"
      assert html =~ "Bob"
    end

    test "handles missing children gracefully" do
      component = make_component("solo", "Text", %{"text" => "no kids"})
      ctx = make_ctx(%{"solo" => component})
      assigns = %{component: component, ctx: ctx}

      html =
        rendered_to_string(~H"<Renderer.render_children component={@component} ctx={@ctx} />")

      assert html == ""
    end
  end

  describe "default_components/0" do
    test "returns all 18 built-in component types" do
      defaults = Renderer.default_components()

      assert map_size(defaults) == 18

      expected_types = ~w(
        Text Row Column List Button Image Icon Divider Card
        TextField CheckBox ChoicePicker Slider DateTimeInput Tabs Modal
        Video AudioPlayer
      )

      for type <- expected_types do
        assert Map.has_key?(defaults, type), "missing type: #{type}"
      end
    end

    test "maps types to their expected modules" do
      defaults = Renderer.default_components()
      assert defaults["Text"] == A2UI.Components.Text
      assert defaults["Button"] == A2UI.Components.Button
      assert defaults["List"] == A2UI.Components.ListComponent
    end
  end

  describe "resolve_prop/4" do
    test "resolves literal values" do
      ctx = make_ctx(%{})
      assert Renderer.resolve_prop(%{"text" => "hi"}, "text", ctx) == "hi"
    end

    test "resolves path bindings" do
      ctx = make_ctx(%{}, "s1", data: %{"user" => "Alice"})
      assert Renderer.resolve_prop(%{"name" => %{"path" => "/user"}}, "name", ctx) == "Alice"
    end

    test "returns fallback on missing key" do
      ctx = make_ctx(%{})
      assert Renderer.resolve_prop(%{}, "missing", ctx, "default") == "default"
    end

    test "returns fallback on unresolvable binding" do
      ctx = make_ctx(%{})
      assert Renderer.resolve_prop(%{"x" => %{"path" => "/nope"}}, "x", ctx, "fb") == "fb"
    end
  end

  describe "a11y_attrs/1" do
    test "returns empty map for nil" do
      assert Renderer.a11y_attrs(nil) == %{}
    end

    test "maps label and role" do
      attrs = Renderer.a11y_attrs(%{"label" => "Close", "role" => "button"})
      assert attrs == %{:"aria-label" => "Close", role: "button"}
    end

    test "handles partial accessibility" do
      assert Renderer.a11y_attrs(%{"label" => "Hi"}) == %{:"aria-label" => "Hi"}
      assert Renderer.a11y_attrs(%{"role" => "nav"}) == %{role: "nav"}
    end
  end

  describe "layout_classes/1" do
    test "returns justify and align classes" do
      classes = Renderer.layout_classes(%{"justify" => "center", "align" => "end"})
      assert classes == ["a2ui-justify-center", "a2ui-align-end"]
    end

    test "returns empty list when no layout props" do
      assert Renderer.layout_classes(%{}) == []
    end

    test "handles spaceBetween" do
      classes = Renderer.layout_classes(%{"justify" => "spaceBetween"})
      assert classes == ["a2ui-justify-space-between"]
    end
  end

  describe "weight_style/1" do
    test "returns custom property for weight" do
      assert Renderer.weight_style(%{"weight" => 2}) == "--a2ui-weight: 2"
    end

    test "returns nil when no weight" do
      assert Renderer.weight_style(%{}) == nil
    end
  end

  describe "binding_path/1" do
    test "extracts path from binding" do
      assert Renderer.binding_path(%{"path" => "/user/name"}) == "/user/name"
    end

    test "returns nil for non-binding" do
      assert Renderer.binding_path("literal") == nil
      assert Renderer.binding_path(nil) == nil
    end
  end
end
