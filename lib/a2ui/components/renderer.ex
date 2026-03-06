defmodule A2UI.Components.Renderer do
  @moduledoc """
  Entry point for rendering A2UI surfaces as Phoenix function components.

  Dispatches each component type to its module via a compile-time map.
  """

  use Phoenix.Component

  alias A2UI.{ComponentTree, DataModel.Binding}
  alias A2UI.Components.RenderContext

  @type_modules %{
    "Text" => A2UI.Components.Text,
    "Row" => A2UI.Components.Row,
    "Column" => A2UI.Components.Column,
    "List" => A2UI.Components.ListComponent,
    "Button" => A2UI.Components.Button,
    "Image" => A2UI.Components.Image,
    "Icon" => A2UI.Components.Icon,
    "Divider" => A2UI.Components.Divider,
    "Card" => A2UI.Components.Card,
    "TextField" => A2UI.Components.TextField,
    "CheckBox" => A2UI.Components.CheckBox,
    "ChoicePicker" => A2UI.Components.ChoicePicker,
    "Slider" => A2UI.Components.Slider,
    "DateTimeInput" => A2UI.Components.DateTimeInput,
    "Tabs" => A2UI.Components.Tabs,
    "Modal" => A2UI.Components.Modal
  }

  # ── Public function components ──

  @doc """
  Renders an entire A2UI surface. Finds the root component and renders the tree.

  ## Assigns
  - `surface` — `%A2UI.Surface{}`
  """
  attr :surface, :any, required: true

  def surface(assigns) do
    ctx = RenderContext.from_surface(assigns.surface)

    case ComponentTree.root(ctx.components) do
      {:ok, root_component} ->
        assigns = assign(assigns, component: root_component, ctx: ctx)

        ~H"""
        <div class="a2ui-surface" data-surface-id={@ctx.surface_id}>
          <.component component={@component} ctx={@ctx} />
        </div>
        """

      {:error, :no_root} ->
        ~H"""
        <div class="a2ui-surface a2ui-surface--empty"></div>
        """
    end
  end

  @doc """
  Renders a single component by dispatching to its type module.

  ## Assigns
  - `component` — `%A2UI.Component{}`
  - `ctx` — `%RenderContext{}`
  """
  attr :component, :any, required: true
  attr :ctx, :any, required: true

  def component(assigns) do
    case Map.get(@type_modules, assigns.component.type) do
      nil ->
        ~H"""
        <div class="a2ui-unknown" data-type={@component.type} data-id={@component.id}>
          Unknown component: {@component.type}
        </div>
        """

      module ->
        assigns = assign(assigns, module: module)

        ~H"""
        <.live_component_fn module={@module} component={@component} ctx={@ctx} />
        """
    end
  end

  # Trampoline to call module.render/1 from HEEx
  defp live_component_fn(assigns) do
    assigns.module.render(assigns)
  end

  @doc """
  Renders children of a component using ComponentTree.child_ids/1.

  Handles static children (IDs list), template children, and no children.

  ## Assigns
  - `component` — `%A2UI.Component{}`
  - `ctx` — `%RenderContext{}`
  """
  attr :component, :any, required: true
  attr :ctx, :any, required: true

  def render_children(assigns) do
    case ComponentTree.child_ids(assigns.component) do
      {:ids, ids} ->
        children =
          Enum.map(ids, fn id ->
            Map.get(assigns.ctx.components, id)
          end)
          |> Enum.reject(&is_nil/1)

        assigns = assign(assigns, children: children)

        ~H"""
        <.component :for={child <- @children} component={child} ctx={@ctx} />
        """

      {:template, config} ->
        render_template_children(assigns, config)

      {:none, []} ->
        ~H""
    end
  end

  defp render_template_children(assigns, config) do
    base_path = assigns.ctx.scope_path || ""

    case ComponentTree.expand_template(config, assigns.ctx.data_model, base_path) do
      {:ok, entries} ->
        template_id = config["componentId"]
        template_component = Map.get(assigns.ctx.components, template_id)

        if template_component do
          children =
            Enum.map(entries, fn {virtual_id, _index, scope_path} ->
              {%{template_component | id: virtual_id}, scope_path}
            end)

          assigns = assign(assigns, children: children)

          ~H"""
          <.component
            :for={{child, scope_path} <- @children}
            component={child}
            ctx={RenderContext.with_scope(@ctx, scope_path)}
          />
          """
        else
          ~H""
        end

      {:error, _reason} ->
        ~H""
    end
  end

  # ── Helpers (used by component modules) ──

  @doc """
  Resolves a prop value through data binding.

  Returns the resolved value or the fallback if resolution fails.
  """
  @spec resolve_prop(map(), String.t(), RenderContext.t(), any()) :: any()
  def resolve_prop(props, key, ctx, fallback \\ nil) do
    case Map.get(props, key) do
      nil ->
        fallback

      value ->
        case Binding.resolve(value, ctx.data_model, ctx.scope_path) do
          {:ok, resolved} -> resolved
          :error -> fallback
        end
    end
  end

  @doc """
  Builds a map of ARIA/accessibility attributes from the component's accessibility field.

  Returns an empty map if accessibility is nil.
  """
  @spec a11y_attrs(map() | nil) :: map()
  def a11y_attrs(nil), do: %{}

  def a11y_attrs(accessibility) when is_map(accessibility) do
    attrs = %{}

    attrs =
      case Map.get(accessibility, "label") do
        nil -> attrs
        label -> Map.put(attrs, :"aria-label", label)
      end

    case Map.get(accessibility, "role") do
      nil -> attrs
      role -> Map.put(attrs, :role, role)
    end
  end

  @doc """
  Extracts the data model path from a binding map.

  Used by input components to set `phx-value-path`.
  """
  @spec binding_path(any()) :: String.t() | nil
  def binding_path(%{"path" => path}), do: path
  def binding_path(_), do: nil

  @doc """
  Builds an inline flex style string from layout props.

  `direction` is `"row"` or `"column"`.
  """
  @spec flex_style(map(), String.t()) :: String.t()
  def flex_style(props, direction) do
    justify = justify_value(Map.get(props, "justify"))
    align = align_value(Map.get(props, "align"))
    weight = Map.get(props, "weight")

    parts = ["display:flex", "flex-direction:#{direction}"]
    parts = if justify, do: parts ++ ["justify-content:#{justify}"], else: parts
    parts = if align, do: parts ++ ["align-items:#{align}"], else: parts
    parts = if weight, do: parts ++ ["flex-grow:#{weight}"], else: parts

    Enum.join(parts, ";")
  end

  @justify_map %{
    "start" => "flex-start",
    "center" => "center",
    "end" => "flex-end",
    "spaceBetween" => "space-between",
    "spaceAround" => "space-around",
    "spaceEvenly" => "space-evenly"
  }

  @align_map %{
    "start" => "flex-start",
    "center" => "center",
    "end" => "flex-end",
    "stretch" => "stretch"
  }

  defp justify_value(nil), do: nil
  defp justify_value(v), do: Map.get(@justify_map, v)

  defp align_value(nil), do: nil
  defp align_value(v), do: Map.get(@align_map, v)
end
