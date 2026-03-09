defmodule A2UI.Components.Icon do
  @moduledoc """
  Renders an A2UI Icon component.

  Produces a generic icon element. Actual display depends on the user's icon font.
  """

  use A2UI.ComponentRenderer

  attr(:component, :any, required: true)
  attr(:ctx, :any, required: true)

  @impl true
  def render(assigns) do
    props = assigns.component.props
    name = resolve_prop(props, "name", assigns.ctx, "")
    a11y = a11y_attrs(assigns.component.accessibility)

    assigns = assign(assigns, name: name, a11y: a11y)

    ~H"""
    <span class="a2ui-icon" {@a11y}>
      <i class={"a2ui-icon--#{@name}"}></i>
    </span>
    """
  end
end
