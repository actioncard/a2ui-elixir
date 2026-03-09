defmodule A2UI.Components.Button do
  @moduledoc """
  Renders an A2UI Button component.

  Emits `phx-click="a2ui_action"` for server actions, `data-a2ui-action` for local actions.
  """

  use A2UI.ComponentRenderer

  attr(:component, :any, required: true)
  attr(:ctx, :any, required: true)

  @impl true
  def render(assigns) do
    props = assigns.component.props
    variant = Map.get(props, "variant", "default")
    action = Map.get(props, "action")
    a11y = a11y_attrs(assigns.component.accessibility)
    class = "a2ui-button a2ui-button--#{variant}"
    action_attrs = action_attrs(action, assigns.component.id, assigns.ctx.surface_id)

    child = resolve_child(props, "child", assigns.ctx)

    assigns = assign(assigns, class: class, a11y: a11y, action_attrs: action_attrs, child: child)

    ~H"""
    <button class={@class} {@action_attrs} {@a11y}>
      <.component :if={@child} component={@child} ctx={@ctx} />
    </button>
    """
  end

  defp action_attrs(nil, _component_id, _surface_id), do: %{}

  defp action_attrs(%{"event" => event}, component_id, surface_id) do
    %{
      "phx-click" => "a2ui_action",
      "phx-value-surface-id" => surface_id,
      "phx-value-component-id" => component_id,
      "phx-value-action" => Jason.encode!(event)
    }
  end

  defp action_attrs(%{"functionCall" => function_call}, _component_id, _surface_id) do
    %{
      "data-a2ui-action" => Jason.encode!(function_call)
    }
  end

  defp action_attrs(_unknown, _component_id, _surface_id), do: %{}
end
