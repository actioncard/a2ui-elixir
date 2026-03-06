defmodule A2UI.Components.InputTest do
  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]
  import A2UI.Test.ComponentHelpers

  alias A2UI.Components.Renderer

  describe "TextField component" do
    test "renders text input by default" do
      component = make_component("tf", "TextField", %{
        "label" => "Name",
        "value" => %{"path" => "/name"}
      })

      ctx = make_ctx(%{"tf" => component}, "s1", data: %{"name" => "Alice"})
      assigns = %{component: component, ctx: ctx}

      html = rendered_to_string(~H"<Renderer.component component={@component} ctx={@ctx} />")

      assert html =~ "a2ui-text-field"
      assert html =~ "<label"
      assert html =~ "Name"
      assert html =~ ~s(type="text")
      assert html =~ ~s(value="Alice")
      assert html =~ ~s(phx-change="a2ui_input_change")
      assert html =~ ~s(phx-value-path="/name")
      assert html =~ ~s(phx-value-surface-id="s1")
    end

    test "renders number input" do
      component = make_component("tf", "TextField", %{
        "textFieldType" => "number",
        "value" => %{"path" => "/age"}
      })

      ctx = make_ctx(%{"tf" => component}, "s1", data: %{"age" => 25})
      assigns = %{component: component, ctx: ctx}

      html = rendered_to_string(~H"<Renderer.component component={@component} ctx={@ctx} />")

      assert html =~ ~s(type="number")
    end

    test "renders password input for obscured" do
      component = make_component("tf", "TextField", %{
        "textFieldType" => "obscured",
        "value" => "secret"
      })

      ctx = make_ctx(%{"tf" => component})
      assigns = %{component: component, ctx: ctx}

      html = rendered_to_string(~H"<Renderer.component component={@component} ctx={@ctx} />")

      assert html =~ ~s(type="password")
    end

    test "renders textarea for longText" do
      component = make_component("tf", "TextField", %{
        "textFieldType" => "longText",
        "label" => "Bio",
        "value" => %{"path" => "/bio"}
      })

      ctx = make_ctx(%{"tf" => component}, "s1", data: %{"bio" => "Hello world"})
      assigns = %{component: component, ctx: ctx}

      html = rendered_to_string(~H"<Renderer.component component={@component} ctx={@ctx} />")

      assert html =~ "<textarea"
      assert html =~ "Hello world"
      assert html =~ "Bio"
    end

    test "renders checks as data attribute" do
      checks = [
        %{"call" => "required", "message" => "Required"},
        %{"call" => "email", "message" => "Invalid email"}
      ]

      component = make_component("tf", "TextField", %{
        "value" => "test",
        "checks" => checks
      })

      ctx = make_ctx(%{"tf" => component})
      assigns = %{component: component, ctx: ctx}

      html = rendered_to_string(~H"<Renderer.component component={@component} ctx={@ctx} />")

      assert html =~ "data-a2ui-checks"
      assert html =~ "required"
    end

    test "renders without phx attrs when value is literal" do
      component = make_component("tf", "TextField", %{"value" => "static"})
      ctx = make_ctx(%{"tf" => component})
      assigns = %{component: component, ctx: ctx}

      html = rendered_to_string(~H"<Renderer.component component={@component} ctx={@ctx} />")

      refute html =~ "phx-change"
    end
  end

  describe "CheckBox component" do
    test "renders checkbox with label" do
      component = make_component("cb", "CheckBox", %{
        "label" => "Agree to terms",
        "value" => %{"path" => "/agreed"}
      })

      ctx = make_ctx(%{"cb" => component}, "s1", data: %{"agreed" => true})
      assigns = %{component: component, ctx: ctx}

      html = rendered_to_string(~H"<Renderer.component component={@component} ctx={@ctx} />")

      assert html =~ "a2ui-checkbox"
      assert html =~ ~s(type="checkbox")
      assert html =~ "Agree to terms"
      assert html =~ "checked"
      assert html =~ ~s(phx-change="a2ui_input_change")
    end

    test "renders unchecked when false" do
      component = make_component("cb", "CheckBox", %{
        "label" => "Check me",
        "value" => %{"path" => "/flag"}
      })

      ctx = make_ctx(%{"cb" => component}, "s1", data: %{"flag" => false})
      assigns = %{component: component, ctx: ctx}

      html = rendered_to_string(~H"<Renderer.component component={@component} ctx={@ctx} />")

      # Phoenix renders checked={false} as absence of the attribute
      {:ok, doc} = Floki.parse_document(html)
      [input] = Floki.find(doc, "input[type=checkbox]")
      {_, attrs, _} = input
      refute Enum.any?(attrs, fn {k, _} -> k == "checked" end)
    end
  end

  describe "ChoicePicker component" do
    test "renders radio buttons for single selection" do
      component = make_component("cp", "ChoicePicker", %{
        "options" => [
          %{"label" => "Red", "value" => "red"},
          %{"label" => "Blue", "value" => "blue"}
        ],
        "selections" => %{"path" => "/color"},
        "maxAllowedSelections" => 1
      })

      ctx = make_ctx(%{"cp" => component}, "s1", data: %{"color" => ["red"]})
      assigns = %{component: component, ctx: ctx}

      html = rendered_to_string(~H"<Renderer.component component={@component} ctx={@ctx} />")

      assert html =~ "a2ui-choice-picker"
      assert html =~ ~s(type="radio")
      assert html =~ "Red"
      assert html =~ "Blue"
    end

    test "renders checkboxes for multi selection" do
      component = make_component("cp", "ChoicePicker", %{
        "options" => [
          %{"label" => "A", "value" => "a"},
          %{"label" => "B", "value" => "b"}
        ],
        "selections" => %{"path" => "/selected"},
        "maxAllowedSelections" => 3
      })

      ctx = make_ctx(%{"cp" => component}, "s1", data: %{"selected" => ["a"]})
      assigns = %{component: component, ctx: ctx}

      html = rendered_to_string(~H"<Renderer.component component={@component} ctx={@ctx} />")

      assert html =~ ~s(type="checkbox")
    end

    test "renders with fieldset" do
      component = make_component("cp", "ChoicePicker", %{
        "options" => [%{"label" => "X", "value" => "x"}],
        "selections" => []
      })

      ctx = make_ctx(%{"cp" => component})
      assigns = %{component: component, ctx: ctx}

      html = rendered_to_string(~H"<Renderer.component component={@component} ctx={@ctx} />")

      assert html =~ "<fieldset"
    end
  end

  describe "Slider component" do
    test "renders range input" do
      component = make_component("sl", "Slider", %{
        "value" => %{"path" => "/volume"},
        "minValue" => 0,
        "maxValue" => 100
      })

      ctx = make_ctx(%{"sl" => component}, "s1", data: %{"volume" => 75})
      assigns = %{component: component, ctx: ctx}

      html = rendered_to_string(~H"<Renderer.component component={@component} ctx={@ctx} />")

      assert html =~ "a2ui-slider"
      assert html =~ ~s(type="range")
      assert html =~ ~s(min="0")
      assert html =~ ~s(max="100")
      assert html =~ ~s(value="75")
      assert html =~ ~s(phx-change="a2ui_input_change")
    end

    test "uses default min/max" do
      component = make_component("sl", "Slider", %{"value" => 50})
      ctx = make_ctx(%{"sl" => component})
      assigns = %{component: component, ctx: ctx}

      html = rendered_to_string(~H"<Renderer.component component={@component} ctx={@ctx} />")

      assert html =~ ~s(min="0")
      assert html =~ ~s(max="100")
    end
  end

  describe "DateTimeInput component" do
    test "renders date input when enableDate only" do
      component = make_component("dt", "DateTimeInput", %{
        "label" => "Date",
        "value" => %{"path" => "/date"},
        "enableDate" => true
      })

      ctx = make_ctx(%{"dt" => component}, "s1", data: %{"date" => "2025-12-15"})
      assigns = %{component: component, ctx: ctx}

      html = rendered_to_string(~H"<Renderer.component component={@component} ctx={@ctx} />")

      assert html =~ "a2ui-datetime-input"
      assert html =~ ~s(type="date")
      assert html =~ ~s(value="2025-12-15")
      assert html =~ "Date"
    end

    test "renders time input when enableTime only" do
      component = make_component("dt", "DateTimeInput", %{
        "enableTime" => true,
        "value" => "19:00"
      })

      ctx = make_ctx(%{"dt" => component})
      assigns = %{component: component, ctx: ctx}

      html = rendered_to_string(~H"<Renderer.component component={@component} ctx={@ctx} />")

      assert html =~ ~s(type="time")
    end

    test "renders datetime-local when both enabled" do
      component = make_component("dt", "DateTimeInput", %{
        "enableDate" => true,
        "enableTime" => true,
        "value" => "2025-12-15T19:00"
      })

      ctx = make_ctx(%{"dt" => component})
      assigns = %{component: component, ctx: ctx}

      html = rendered_to_string(~H"<Renderer.component component={@component} ctx={@ctx} />")

      assert html =~ ~s(type="datetime-local")
    end

    test "defaults to date when neither flag set" do
      component = make_component("dt", "DateTimeInput", %{"value" => ""})
      ctx = make_ctx(%{"dt" => component})
      assigns = %{component: component, ctx: ctx}

      html = rendered_to_string(~H"<Renderer.component component={@component} ctx={@ctx} />")

      assert html =~ ~s(type="date")
    end
  end
end
