defmodule A2UI.Components.Column do
  @moduledoc """
  Renders an A2UI Column component — a vertical flex container.
  """

  use A2UI.ComponentRenderer

  attr(:component, :any, required: true)
  attr(:ctx, :any, required: true)

  @impl true
  def render(assigns) do
    props = assigns.component.props
    classes = ["a2ui-column" | layout_classes(props)]
    style = weight_style(props)
    a11y = a11y_attrs(assigns.component.accessibility)

    assigns = assign(assigns, classes: classes, style: style, a11y: a11y)

    ~H"""
    <div class={@classes} style={@style} {@a11y}>
      <.render_children component={@component} ctx={@ctx} />
    </div>
    """
  end
end
