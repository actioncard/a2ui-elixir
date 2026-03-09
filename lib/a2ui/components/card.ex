defmodule A2UI.Components.Card do
  @moduledoc """
  Renders an A2UI Card component — a container with a single child.
  """

  use A2UI.ComponentRenderer

  attr(:component, :any, required: true)
  attr(:ctx, :any, required: true)

  @impl true
  def render(assigns) do
    props = assigns.component.props
    a11y = a11y_attrs(assigns.component.accessibility)

    child = resolve_child(props, "child", assigns.ctx)

    assigns = assign(assigns, a11y: a11y, child: child)

    ~H"""
    <div class="a2ui-card" {@a11y}>
      <.component :if={@child} component={@child} ctx={@ctx} />
    </div>
    """
  end
end
