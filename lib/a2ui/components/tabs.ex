defmodule A2UI.Components.Tabs do
  @moduledoc """
  Renders an A2UI Tabs component.

  `tabItems` prop is an array of `%{"title" => str, "child" => id}`.
  First tab is active by default, rest are hidden. Tab switching deferred to Phase 4 JS hook.
  """

  use A2UI.ComponentRenderer

  attr(:component, :any, required: true)
  attr(:ctx, :any, required: true)

  @impl true
  def render(assigns) do
    props = assigns.component.props
    tab_items = Map.get(props, "tabItems", [])
    a11y = a11y_attrs(assigns.component.accessibility)

    tabs =
      tab_items
      |> Enum.with_index()
      |> Enum.map(fn {item, index} ->
        child = resolve_child(item, "child", assigns.ctx)
        %{title: item["title"], child: child, active: index == 0, index: index}
      end)

    assigns = assign(assigns, tabs: tabs, a11y: a11y, component_id: assigns.component.id)

    ~H"""
    <div class="a2ui-tabs" id={@component_id} {@a11y}>
      <div class="a2ui-tabs__bar" role="tablist">
        <button
          :for={tab <- @tabs}
          class={"a2ui-tabs__tab#{if tab.active, do: " a2ui-tabs__tab--active", else: ""}"}
          role="tab"
          aria-selected={to_string(tab.active)}
          data-tab-index={tab.index}
        >
          {tab.title}
        </button>
      </div>
      <div
        :for={tab <- @tabs}
        class={"a2ui-tabs__panel#{if tab.active, do: " a2ui-tabs__panel--active", else: ""}"}
        role="tabpanel"
        style={unless tab.active, do: "display:none"}
      >
        <.component :if={tab.child} component={tab.child} ctx={@ctx} />
      </div>
    </div>
    """
  end
end
