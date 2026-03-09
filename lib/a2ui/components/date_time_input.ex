defmodule A2UI.Components.DateTimeInput do
  @moduledoc """
  Renders an A2UI DateTimeInput component.

  Type determined by `enableDate`/`enableTime` flags:
  - date only → `<input type="date">`
  - time only → `<input type="time">`
  - both → `<input type="datetime-local">`
  """

  use A2UI.ComponentRenderer

  attr(:component, :any, required: true)
  attr(:ctx, :any, required: true)

  @impl true
  def render(assigns) do
    props = assigns.component.props
    label = resolve_prop(props, "label", assigns.ctx)
    value = resolve_prop(props, "value", assigns.ctx, "")
    enable_date = Map.get(props, "enableDate", false)
    enable_time = Map.get(props, "enableTime", false)
    html_type = input_type(enable_date, enable_time)
    path = binding_path(Map.get(props, "value"))
    a11y = a11y_attrs(assigns.component.accessibility)
    surface_id = assigns.ctx.surface_id
    form_attrs = input_attrs(path, surface_id)

    assigns =
      assign(assigns,
        label: label,
        value: value,
        html_type: html_type,
        a11y: a11y,
        form_attrs: form_attrs,
        component_id: assigns.component.id
      )

    ~H"""
    <form class="a2ui-datetime-input" {@form_attrs} {@a11y}>
      <label :if={@label} for={@component_id}>{@label}</label>
      <input
        type={@html_type}
        id={@component_id}
        name={@component_id}
        value={@value}
        class="a2ui-datetime-input__input"
      />
    </form>
    """
  end

  defp input_type(true, true), do: "datetime-local"
  defp input_type(true, false), do: "date"
  defp input_type(false, true), do: "time"
  defp input_type(false, false), do: "date"
end
