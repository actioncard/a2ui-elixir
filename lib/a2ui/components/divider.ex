defmodule A2UI.Components.Divider do
  @moduledoc """
  Renders an A2UI Divider component.

  Horizontal (default): `<hr>`. Vertical: `<div role="separator">`.
  """

  use Phoenix.Component

  alias A2UI.Components.Renderer

  attr(:component, :any, required: true)
  attr(:ctx, :any, required: true)

  def render(assigns) do
    props = assigns.component.props
    axis = Map.get(props, "axis", "horizontal")
    a11y = Renderer.a11y_attrs(assigns.component.accessibility)

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
