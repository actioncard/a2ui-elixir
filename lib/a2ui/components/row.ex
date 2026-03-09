defmodule A2UI.Components.Row do
  @moduledoc """
  Renders an A2UI Row component — a horizontal flex container.
  """

  use A2UI.ComponentRenderer

  attr(:component, :any, required: true)
  attr(:ctx, :any, required: true)

  @impl true
  def render(assigns) do
    props = assigns.component.props
    style = flex_style(props, "row")
    a11y = a11y_attrs(assigns.component.accessibility)

    assigns = assign(assigns, style: style, a11y: a11y)

    ~H"""
    <div class="a2ui-row" style={@style} {@a11y}>
      <.render_children component={@component} ctx={@ctx} />
    </div>
    """
  end
end
