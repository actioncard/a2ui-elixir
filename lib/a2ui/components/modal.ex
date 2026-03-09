defmodule A2UI.Components.Modal do
  @moduledoc """
  Renders an A2UI Modal component.

  Has `entryPointChild` (always visible) and `contentChild` (overlay, hidden by default).
  Toggle deferred to Phase 4 JS hook.
  """

  use A2UI.ComponentRenderer

  attr(:component, :any, required: true)
  attr(:ctx, :any, required: true)

  @impl true
  def render(assigns) do
    props = assigns.component.props
    a11y = a11y_attrs(assigns.component.accessibility)

    entry_child =
      case Map.get(props, "entryPointChild") do
        nil -> nil
        id -> Map.get(assigns.ctx.components, id)
      end

    content_child =
      case Map.get(props, "contentChild") do
        nil -> nil
        id -> Map.get(assigns.ctx.components, id)
      end

    assigns =
      assign(assigns,
        a11y: a11y,
        entry_child: entry_child,
        content_child: content_child,
        component_id: assigns.component.id
      )

    ~H"""
    <div class="a2ui-modal" id={@component_id} {@a11y}>
      <div :if={@entry_child} class="a2ui-modal__entry">
        <.component component={@entry_child} ctx={@ctx} />
      </div>
      <div :if={@content_child} class="a2ui-modal__overlay" style="display:none" role="dialog">
        <div class="a2ui-modal__content">
          <.component component={@content_child} ctx={@ctx} />
        </div>
      </div>
    </div>
    """
  end
end
