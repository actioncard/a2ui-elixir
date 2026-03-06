defmodule A2UI.Components.Slider do
  @moduledoc """
  Renders an A2UI Slider component.
  """

  use Phoenix.Component

  alias A2UI.Components.Renderer

  attr(:component, :any, required: true)
  attr(:ctx, :any, required: true)

  def render(assigns) do
    props = assigns.component.props
    value = Renderer.resolve_prop(props, "value", assigns.ctx, 0)
    min_val = Map.get(props, "minValue", 0)
    max_val = Map.get(props, "maxValue", 100)
    path = Renderer.binding_path(Map.get(props, "value"))
    a11y = Renderer.a11y_attrs(assigns.component.accessibility)
    surface_id = assigns.ctx.surface_id
    input_attrs = input_attrs(path, surface_id)

    assigns =
      assign(assigns,
        value: value,
        min_val: min_val,
        max_val: max_val,
        a11y: a11y,
        input_attrs: input_attrs,
        component_id: assigns.component.id
      )

    ~H"""
    <div class="a2ui-slider" {@a11y}>
      <input
        type="range"
        id={@component_id}
        name={@component_id}
        min={@min_val}
        max={@max_val}
        value={@value}
        {@input_attrs}
      />
    </div>
    """
  end

  defp input_attrs(nil, _surface_id), do: %{}

  defp input_attrs(path, surface_id) do
    %{
      "phx-change" => "a2ui_input_change",
      "phx-value-path" => path,
      "phx-value-surface-id" => surface_id
    }
  end
end
