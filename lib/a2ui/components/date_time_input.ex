defmodule A2UI.Components.DateTimeInput do
  @moduledoc """
  Renders an A2UI DateTimeInput component.

  Type determined by `enableDate`/`enableTime` flags:
  - date only → `<input type="date">`
  - time only → `<input type="time">`
  - both → `<input type="datetime-local">`
  """

  use Phoenix.Component

  alias A2UI.Components.Renderer

  attr(:component, :any, required: true)
  attr(:ctx, :any, required: true)

  def render(assigns) do
    props = assigns.component.props
    label = Renderer.resolve_prop(props, "label", assigns.ctx)
    value = Renderer.resolve_prop(props, "value", assigns.ctx, "")
    enable_date = Map.get(props, "enableDate", false)
    enable_time = Map.get(props, "enableTime", false)
    html_type = input_type(enable_date, enable_time)
    path = Renderer.binding_path(Map.get(props, "value"))
    a11y = Renderer.a11y_attrs(assigns.component.accessibility)
    surface_id = assigns.ctx.surface_id
    input_attrs = input_attrs(path, surface_id)

    assigns =
      assign(assigns,
        label: label,
        value: value,
        html_type: html_type,
        a11y: a11y,
        input_attrs: input_attrs,
        component_id: assigns.component.id
      )

    ~H"""
    <div class="a2ui-datetime-input" {@a11y}>
      <label :if={@label} for={@component_id}>{@label}</label>
      <input
        type={@html_type}
        id={@component_id}
        name={@component_id}
        value={@value}
        class="a2ui-datetime-input__input"
        {@input_attrs}
      />
    </div>
    """
  end

  defp input_type(true, true), do: "datetime-local"
  defp input_type(true, false), do: "date"
  defp input_type(false, true), do: "time"
  defp input_type(false, false), do: "date"

  defp input_attrs(nil, _surface_id), do: %{}

  defp input_attrs(path, surface_id) do
    %{
      "phx-change" => "a2ui_input_change",
      "phx-value-path" => path,
      "phx-value-surface-id" => surface_id
    }
  end
end
