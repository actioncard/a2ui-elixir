defmodule A2UI.Components.Divider do
  @moduledoc """
  Renders an A2UI Divider component.

  Horizontal (default): `<hr>`. Vertical: `<div role="separator">`.
  """

  use A2UI.ComponentRenderer

  attr(:component, :any, required: true)
  attr(:ctx, :any, required: true)

  @impl true
  def render(assigns) do
    props = assigns.component.props
    axis = Map.get(props, "axis", "horizontal")
    a11y = a11y_attrs(assigns.component.accessibility)

    assigns = assign(assigns, axis: axis, a11y: a11y)

    case axis do
      "vertical" ->
        ~H"""
        <div class="a2ui-divider a2ui-divider--vertical" role="separator" {@a11y}></div>
        """

      _ ->
        ~H"""
        <hr class="a2ui-divider a2ui-divider--horizontal" {@a11y} />
        """
    end
  end
end
