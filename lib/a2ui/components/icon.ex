defmodule A2UI.Components.Icon do
  @moduledoc """
  Renders an A2UI Icon component.

  Produces a generic icon element. Actual display depends on the user's icon font.
  """

  use Phoenix.Component

  alias A2UI.Components.Renderer

  attr :component, :any, required: true
  attr :ctx, :any, required: true

  def render(assigns) do
    props = assigns.component.props
    name = Renderer.resolve_prop(props, "name", assigns.ctx, "")
    a11y = Renderer.a11y_attrs(assigns.component.accessibility)

    assigns = assign(assigns, name: name, a11y: a11y)

    ~H"""
    <span class="a2ui-icon" {@a11y}>
      <i class={"a2ui-icon--#{@name}"}></i>
    </span>
    """
  end
end
