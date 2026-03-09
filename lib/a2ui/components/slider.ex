defmodule A2UI.Components.Slider do
  @moduledoc """
  Renders an A2UI Slider component.
  """

  use A2UI.ComponentRenderer

  attr(:component, :any, required: true)
  attr(:ctx, :any, required: true)

  @impl true
  def render(assigns) do
    props = assigns.component.props
    value = resolve_prop(props, "value", assigns.ctx, 0)
    min_val = Map.get(props, "minValue", 0)
    max_val = Map.get(props, "maxValue", 100)
    path = binding_path(Map.get(props, "value"))
    a11y = a11y_attrs(assigns.component.accessibility)
    surface_id = assigns.ctx.surface_id
    form_attrs = input_attrs(path, surface_id)

    assigns =
      assign(assigns,
        value: value,
        min_val: min_val,
        max_val: max_val,
        a11y: a11y,
        form_attrs: form_attrs,
        component_id: assigns.component.id
      )

    ~H"""
    <form class="a2ui-slider" {@form_attrs} {@a11y}>
      <input
        type="range"
        id={@component_id}
        name={@component_id}
        min={@min_val}
        max={@max_val}
        value={@value}
      />
    </form>
    """
  end
end
