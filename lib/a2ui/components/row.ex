defmodule A2UI.Components.Row do
  @moduledoc """
  Renders an A2UI Row component — a horizontal flex container.
  """

  use Phoenix.Component

  alias A2UI.Components.Renderer

  attr :component, :any, required: true
  attr :ctx, :any, required: true

  def render(assigns) do
    props = assigns.component.props
    style = Renderer.flex_style(props, "row")
    a11y = Renderer.a11y_attrs(assigns.component.accessibility)

    assigns = assign(assigns, style: style, a11y: a11y)

    ~H"""
    <div class="a2ui-row" style={@style} {@a11y}>
      <Renderer.render_children component={@component} ctx={@ctx} />
    </div>
    """
  end
end
