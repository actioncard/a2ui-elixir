defmodule A2UI.Components.TextField do
  @moduledoc """
  Renders an A2UI TextField component.

  Types: `shortText` → text, `number` → number, `obscured` → password, `longText` → textarea.
  """

  use A2UI.ComponentRenderer

  @type_map %{
    "shortText" => "text",
    "number" => "number",
    "obscured" => "password"
  }

  attr(:component, :any, required: true)
  attr(:ctx, :any, required: true)

  @impl true
  def render(assigns) do
    props = assigns.component.props
    label = resolve_prop(props, "label", assigns.ctx)
    value = resolve_prop(props, "value", assigns.ctx, "")
    field_type = Map.get(props, "textFieldType", "shortText")
    path = binding_path(Map.get(props, "value"))
    checks = Map.get(props, "checks")
    a11y = a11y_attrs(assigns.component.accessibility)
    surface_id = assigns.ctx.surface_id

    input_attrs = input_attrs(path, surface_id)
    check_attrs = if checks, do: %{"data-a2ui-checks" => Jason.encode!(checks)}, else: %{}

    assigns =
      assign(assigns,
        label: label,
        value: value,
        field_type: field_type,
        a11y: a11y,
        input_attrs: input_attrs,
        check_attrs: check_attrs,
        component_id: assigns.component.id
      )

    if field_type == "longText" do
      ~H"""
      <div class="a2ui-text-field" {@a11y}>
        <label :if={@label} for={@component_id}>{@label}</label>
        <textarea
          id={@component_id}
          name={@component_id}
          class="a2ui-text-field__input"
          {@input_attrs}
          {@check_attrs}
        >{@value}</textarea>
      </div>
      """
    else
      html_type = Map.get(@type_map, field_type, "text")
      assigns = assign(assigns, html_type: html_type)

      ~H"""
      <div class="a2ui-text-field" {@a11y}>
        <label :if={@label} for={@component_id}>{@label}</label>
        <input
          type={@html_type}
          id={@component_id}
          name={@component_id}
          value={@value}
          class="a2ui-text-field__input"
          {@input_attrs}
          {@check_attrs}
        />
      </div>
      """
    end
  end
end
