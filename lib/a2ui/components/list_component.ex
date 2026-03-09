defmodule A2UI.Components.ListComponent do
  @moduledoc """
  Renders an A2UI List component.

  A flex container that wraps each child in a `<div role="listitem">`.
  Direction prop: `vertical` (default) → column, `horizontal` → row.
  """

  use A2UI.ComponentRenderer

  alias A2UI.ComponentTree
  alias A2UI.Components.RenderContext

  attr(:component, :any, required: true)
  attr(:ctx, :any, required: true)

  @impl true
  def render(assigns) do
    props = assigns.component.props
    direction = Map.get(props, "direction", "vertical")
    flex_dir = if direction == "horizontal", do: "row", else: "column"
    style = flex_style(props, flex_dir)
    a11y = a11y_attrs(assigns.component.accessibility)
    children = resolve_children(assigns.component, assigns.ctx)

    assigns = assign(assigns, style: style, a11y: a11y, children: children)

    ~H"""
    <div class="a2ui-list" role="list" style={@style} {@a11y}>
      <div :for={{child, scope} <- @children} class="a2ui-list__item" role="listitem">
        <.component component={child} ctx={maybe_scope(@ctx, scope)} />
      </div>
    </div>
    """
  end

  defp resolve_children(component, ctx) do
    case ComponentTree.child_ids(component) do
      {:ids, ids} ->
        ids
        |> Enum.map(&Map.get(ctx.components, &1))
        |> Enum.reject(&is_nil/1)
        |> Enum.map(&{&1, nil})

      {:template, config} ->
        expand_template_children(config, ctx)

      {:none, []} ->
        []
    end
  end

  defp expand_template_children(config, ctx) do
    base_path = ctx.scope_path || ""

    case ComponentTree.expand_template(config, ctx.data_model, base_path) do
      {:ok, entries} ->
        template_id = config["componentId"]
        template = Map.get(ctx.components, template_id)

        if template do
          Enum.map(entries, fn {virtual_id, _index, scope_path} ->
            {%{template | id: virtual_id}, scope_path}
          end)
        else
          []
        end

      {:error, _} ->
        []
    end
  end

  defp maybe_scope(ctx, nil), do: ctx
  defp maybe_scope(ctx, scope_path), do: RenderContext.with_scope(ctx, scope_path)
end
