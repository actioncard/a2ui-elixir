defmodule A2UI.Components.ChoicePicker do
  @moduledoc """
  Renders an A2UI ChoicePicker component.

  Single selection (maxAllowedSelections == 1): radio buttons.
  Multiple selection: checkboxes.
  """

  use A2UI.ComponentRenderer

  attr(:component, :any, required: true)
  attr(:ctx, :any, required: true)

  @impl true
  def render(assigns) do
    props = assigns.component.props
    options = Map.get(props, "options", [])
    selections = resolve_prop(props, "selections", assigns.ctx, [])
    max = Map.get(props, "maxAllowedSelections", 0)
    single = max == 1
    path = binding_path(Map.get(props, "selections"))
    a11y = a11y_attrs(assigns.component.accessibility)
    surface_id = assigns.ctx.surface_id
    input_type = if single, do: "radio", else: "checkbox"
    input_attrs = input_attrs(path, surface_id, input_type)

    assigns =
      assign(assigns,
        options: options,
        selections: selections,
        a11y: a11y,
        input_attrs: input_attrs,
        input_type: input_type,
        component_id: assigns.component.id
      )

    ~H"""
    <fieldset class="a2ui-choice-picker" {@a11y}>
      <div :for={option <- @options} class="a2ui-choice-picker__option">
        <label>
          <input
            type={@input_type}
            name={@component_id}
            value={option["value"]}
            checked={option["value"] in @selections}
            {@input_attrs}
          />
          <span>{option["label"]}</span>
        </label>
      </div>
    </fieldset>
    """
  end
end
