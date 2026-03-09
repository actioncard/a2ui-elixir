defmodule A2UI.Demo.StatusBadge do
  @moduledoc """
  Custom StatusBadge component demonstrating the pluggable component system.

  Renders a colored pill badge based on a `status` prop. Supports data binding
  for both `status` and `label`.

  ## Props

    * `status` — status string (`"confirmed"`, `"pending"`, etc.). Data-bindable.
    * `label` — display text. Defaults to the resolved `status` value. Data-bindable.
  """

  use A2UI.ComponentRenderer

  attr :component, :any, required: true
  attr :ctx, :any, required: true

  @impl true
  def render(assigns) do
    props = assigns.component.props
    status = resolve_prop(props, "status", assigns.ctx, "unknown")
    label = resolve_prop(props, "label", assigns.ctx, status)
    a11y = a11y_attrs(assigns.component.accessibility)

    assigns = assign(assigns, status: status, label: label, a11y: a11y)

    ~H"""
    <span class={"a2ui-status-badge a2ui-status-badge--#{@status}"} {@a11y}>
      {@label}
    </span>
    """
  end
end
