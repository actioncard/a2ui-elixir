defmodule A2UI.Components.CheckBox do
  @moduledoc """
  Renders an A2UI CheckBox component.
  """

  use A2UI.ComponentRenderer

  attr(:component, :any, required: true)
  attr(:ctx, :any, required: true)

  @impl true
  def render(assigns) do
    props = assigns.component.props
    label = resolve_prop(props, "label", assigns.ctx, "")
    checked = resolve_prop(props, "value", assigns.ctx, false)
    path = binding_path(Map.get(props, "value"))
    a11y = a11y_attrs(assigns.component.accessibility)
    surface_id = assigns.ctx.surface_id
    input_attrs = input_attrs(path, surface_id)

    assigns =
      assign(assigns,
        label: label,
        checked: checked,
        a11y: a11y,
        input_attrs: input_attrs,
        component_id: assigns.component.id
      )

    ~H"""
    <div class="a2ui-checkbox" {@a11y}>
      <label>
        <input type="hidden" name={@component_id} value="false" {@input_attrs} />
        <input
          type="checkbox"
          id={@component_id}
          name={@component_id}
          value="true"
          checked={@checked}
          {@input_attrs}
        />
        <span>{@label}</span>
      </label>
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
