defmodule A2UI.Live.IntegrationTest do
  @moduledoc false
  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]

  alias A2UI.{Component, SurfaceManager}
  alias A2UI.Components.Renderer
  alias A2UI.Protocol.Messages.{CreateSurface, UpdateComponents, UpdateDataModel}

  defp build_surfaces do
    {:ok, surfaces} =
      SurfaceManager.apply_message(SurfaceManager.new(), %CreateSurface{surface_id: "s1"})

    {:ok, surfaces} =
      SurfaceManager.apply_message(surfaces, %UpdateDataModel{
        surface_id: "s1",
        path: "/",
        value: %{
          "name" => "Alice",
          "date" => "2025-12-15",
          "volume" => 75,
          "agreed" => true,
          "color" => ["red"]
        },
        has_value: true
      })

    {:ok, surfaces} =
      SurfaceManager.apply_message(surfaces, %UpdateComponents{
        surface_id: "s1",
        components: [
          %Component{
            id: "root",
            type: "Column",
            props: %{"children" => ["tf1", "dt1", "sl1", "cb1", "cp1"]}
          },
          %Component{
            id: "tf1",
            type: "TextField",
            props: %{
              "label" => "Name",
              "value" => %{"path" => "/name"},
              "checks" => [%{"call" => "required", "message" => "Required"}]
            }
          },
          %Component{
            id: "dt1",
            type: "DateTimeInput",
            props: %{
              "label" => "Date",
              "value" => %{"path" => "/date"},
              "enableDate" => true
            }
          },
          %Component{
            id: "sl1",
            type: "Slider",
            props: %{
              "value" => %{"path" => "/volume"},
              "minValue" => 0,
              "maxValue" => 100
            }
          },
          %Component{
            id: "cb1",
            type: "CheckBox",
            props: %{
              "label" => "I agree",
              "value" => %{"path" => "/agreed"}
            }
          },
          %Component{
            id: "cp1",
            type: "ChoicePicker",
            props: %{
              "options" => [
                %{"label" => "Red", "value" => "red"},
                %{"label" => "Blue", "value" => "blue"}
              ],
              "selections" => %{"path" => "/color"},
              "maxAllowedSelections" => 1
            }
          }
        ]
      })

    surfaces
  end

  defp render_surface(surfaces) do
    surface = surfaces["s1"]
    assigns = %{surface: surface}
    rendered_to_string(~H"<Renderer.surface surface={@surface} />")
  end

  defp floki_attr({_tag, attrs, _children}, key) do
    case List.keyfind(attrs, key, 0) do
      {_, value} -> value
      nil -> nil
    end
  end

  describe "form wrappers for all input components" do
    setup do
      surfaces = build_surfaces()
      html = render_surface(surfaces)
      {:ok, doc} = Floki.parse_document(html)
      %{html: html, doc: doc, surfaces: surfaces}
    end

    test "TextField renders in <form> with phx-change", %{doc: doc} do
      [form] = Floki.find(doc, "form.a2ui-text-field")
      assert floki_attr(form, "phx-change") == "a2ui_input_change"
      assert floki_attr(form, "phx-value-path") == "/name"
      assert floki_attr(form, "phx-value-surface-id") == "s1"
    end

    test "DateTimeInput renders in <form> with phx-change", %{doc: doc} do
      [form] = Floki.find(doc, "form.a2ui-datetime-input")
      assert floki_attr(form, "phx-change") == "a2ui_input_change"
      assert floki_attr(form, "phx-value-path") == "/date"
      assert floki_attr(form, "phx-value-surface-id") == "s1"
    end

    test "Slider renders in <form> with phx-change", %{doc: doc} do
      [form] = Floki.find(doc, "form.a2ui-slider")
      assert floki_attr(form, "phx-change") == "a2ui_input_change"
      assert floki_attr(form, "phx-value-path") == "/volume"
      assert floki_attr(form, "phx-value-surface-id") == "s1"
    end

    test "CheckBox renders in <form> with phx-change", %{doc: doc} do
      [form] = Floki.find(doc, "form.a2ui-checkbox")
      assert floki_attr(form, "phx-change") == "a2ui_input_change"
      assert floki_attr(form, "phx-value-path") == "/agreed"
      assert floki_attr(form, "phx-value-surface-id") == "s1"
    end

    test "ChoicePicker renders in <form> with phx-change", %{doc: doc} do
      [form] = Floki.find(doc, "form.a2ui-choice-picker")
      assert floki_attr(form, "phx-change") == "a2ui_input_change"
      assert floki_attr(form, "phx-value-path") == "/color"
      assert floki_attr(form, "phx-value-surface-id") == "s1"
    end

    test "phx-change is NOT on any individual <input> elements", %{doc: doc} do
      inputs = Floki.find(doc, "input")
      assert length(inputs) > 0, "expected at least one input element"

      for input <- inputs do
        refute floki_attr(input, "phx-change"),
               "Found phx-change on <input>: #{Floki.raw_html(input)}"
      end
    end

    test "TextField has validation hook when checks present", %{doc: doc} do
      [form] = Floki.find(doc, "form.a2ui-text-field")
      assert floki_attr(form, "phx-hook") == "A2UIValidation"
      assert floki_attr(form, "data-a2ui-checks")
      assert Floki.find(doc, ".a2ui-text-field__error") != []
    end

    test "ChoicePicker still contains fieldset inside form", %{doc: doc} do
      [form] = Floki.find(doc, "form.a2ui-choice-picker")
      assert Floki.find(form, "fieldset") != []
    end
  end

  describe "input change event handling" do
    setup do
      surfaces = build_surfaces()

      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          __changed__: %{},
          a2ui_surfaces: surfaces
        }
      }

      %{socket: socket}
    end

    test "text field change updates data model", %{socket: socket} do
      params = %{
        "surface-id" => "s1",
        "path" => "/name",
        "_target" => ["tf1"],
        "tf1" => "Bob"
      }

      assert {:noreply, updated} = A2UI.Live.__handle_input_change__(params, socket)

      assert {:ok, "Bob"} =
               A2UI.DataModel.get(updated.assigns.a2ui_surfaces["s1"].data_model, "/name")

      # Re-render and verify the new value appears
      html = render_surface(updated.assigns.a2ui_surfaces)
      assert html =~ ~s(value="Bob")
    end

    test "slider change updates data model with integer coercion", %{socket: socket} do
      params = %{
        "surface-id" => "s1",
        "path" => "/volume",
        "_target" => ["sl1"],
        "sl1" => "50"
      }

      assert {:noreply, updated} = A2UI.Live.__handle_input_change__(params, socket)

      assert {:ok, 50} =
               A2UI.DataModel.get(updated.assigns.a2ui_surfaces["s1"].data_model, "/volume")
    end

    test "checkbox change updates data model with boolean coercion", %{socket: socket} do
      params = %{
        "surface-id" => "s1",
        "path" => "/agreed",
        "_target" => ["cb1"],
        "cb1" => "false"
      }

      assert {:noreply, updated} = A2UI.Live.__handle_input_change__(params, socket)

      assert {:ok, false} =
               A2UI.DataModel.get(updated.assigns.a2ui_surfaces["s1"].data_model, "/agreed")
    end

    test "choice picker change updates data model", %{socket: socket} do
      params = %{
        "surface-id" => "s1",
        "path" => "/color",
        "input-type" => "radio",
        "_target" => ["cp1"],
        "cp1" => "blue"
      }

      assert {:noreply, updated} = A2UI.Live.__handle_input_change__(params, socket)

      assert {:ok, ["blue"]} =
               A2UI.DataModel.get(updated.assigns.a2ui_surfaces["s1"].data_model, "/color")
    end
  end
end
