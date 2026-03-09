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
    has_checks = is_list(checks) and checks != []
    a11y = a11y_attrs(assigns.component.accessibility)
    surface_id = assigns.ctx.surface_id

    form_attrs = input_attrs(path, surface_id)

    hook_attrs =
      if has_checks do
        %{
          "id" => "#{assigns.component.id}-field",
          "phx-hook" => "A2UIValidation",
          "data-a2ui-checks" => Jason.encode!(checks)
        }
      else
        %{}
      end

    assigns =
      assign(assigns,
        label: label,
        value: value,
        field_type: field_type,
        a11y: a11y,
        form_attrs: form_attrs,
        hook_attrs: hook_attrs,
        has_checks: has_checks,
        component_id: assigns.component.id
      )

    if field_type == "longText" do
      ~H"""
      <form class="a2ui-text-field" {@form_attrs} {@hook_attrs} {@a11y}>
        <label :if={@label} for={@component_id}>{@label}</label>
        <textarea
          id={@component_id}
          name={@component_id}
          class="a2ui-text-field__input"
        >{@value}</textarea>
        <span
          :if={@has_checks}
          class="a2ui-text-field__error"
          style="display:none"
        ></span>
      </form>
      """
    else
      html_type = Map.get(@type_map, field_type, "text")
      assigns = assign(assigns, html_type: html_type)

      ~H"""
      <form class="a2ui-text-field" {@form_attrs} {@hook_attrs} {@a11y}>
        <label :if={@label} for={@component_id}>{@label}</label>
        <input
          type={@html_type}
          id={@component_id}
          name={@component_id}
          value={@value}
          class="a2ui-text-field__input"
        />
        <span
          :if={@has_checks}
          class="a2ui-text-field__error"
          style="display:none"
        ></span>
      </form>
      """
    end
  end
end
