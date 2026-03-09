defmodule A2UI.ComponentRenderer do
  @moduledoc """
  Behaviour and convenience macro for building custom A2UI component renderers.

  Every A2UI component type (Text, Button, etc.) is backed by a module that
  implements this behaviour. You can override built-in components or add
  entirely new types by writing a module that `use`s this behaviour and
  registering it in your application config.

  ## Assigns contract

  Your `render/1` function receives assigns with two keys:

    * `assigns.component` — an `%A2UI.Component{}` struct with:
      * `id` — unique component identifier (string)
      * `type` — the component type name, e.g. `"Button"` (string)
      * `props` — component-specific properties (map)
      * `accessibility` — optional ARIA metadata (map or nil)

    * `assigns.ctx` — a `%A2UI.Components.RenderContext{}` with:
      * `components` — map of all component IDs to `%A2UI.Component{}` structs
      * `data_model` — the current `%A2UI.DataModel{}` for binding resolution
      * `surface_id` — the surface this component belongs to
      * `scope_path` — current scope path for template/list bindings

  ## Helpers

  `use A2UI.ComponentRenderer` automatically brings in `Phoenix.Component`
  (giving you `assign/2`, `~H`, `attr/3`, etc.) and imports these helpers
  from `A2UI.Components.Renderer`:

    * `resolve_prop/3,4` — resolve a prop value through data binding.
      `resolve_prop(props, "label", ctx)` returns the resolved value or `nil`.
      Pass a fourth argument for a custom fallback:
      `resolve_prop(props, "count", ctx, 0)`.

    * `a11y_attrs/1` — convert a component's `accessibility` map into an
      ARIA attribute map (e.g. `%{:"aria-label" => "Close", role: "button"}`).
      Returns `%{}` when given `nil`.

    * `binding_path/1` — extract the `"path"` from a binding map.
      Used by input components to set `phx-value-path`.

    * `flex_style/2` — build an inline flex layout style string from props.
      `flex_style(props, "row")` → `"display:flex;flex-direction:row;..."`.

    * `input_attrs/2,3` — build phx-change attribute maps for input components.
      `input_attrs(path, surface_id)` for most inputs;
      `input_attrs(path, surface_id, input_type)` when disambiguation is needed
      (e.g. ChoicePicker). Returns `%{}` when `path` is `nil`.

    * `resolve_child/3` — resolve a single named child component from props.
      `resolve_child(props, "child", ctx)` returns the component or `nil`.

    * `expand_template_entries/2` — expand a template config into
      `{component, scope_path}` tuples for template-based children.

    * `component/1` — render a child component by dispatching to the type
      registry. Expects `component` and `ctx` assigns.

    * `render_children/1` — render all children of a component (handles
      static ID lists, template expansion, and the no-children case).

  ## Example: custom StatusBadge component

      defmodule MyApp.A2UI.StatusBadge do
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

          ~H\"\"\"
          <span class={"a2ui-status-badge a2ui-status-badge--#\{@status}"} {@a11y}>
            {@label}
          </span>
          \"\"\"
        end
      end

  ## Registration

  Register your component in `config/config.exs` (or runtime config):

      config :a2ui, component_modules: %{
        "StatusBadge" => MyApp.A2UI.StatusBadge
      }

  This merges with the built-in components. To also override a built-in,
  just use its type name as the key (e.g. `"Button" => MyApp.A2UI.Button`).

  See `A2UI.Components.Renderer` for more on the compile-time config system.
  """

  @callback render(assigns :: Phoenix.LiveView.Socket.assigns()) :: Phoenix.LiveView.Rendered.t()

  defmacro __using__(_opts) do
    quote do
      @behaviour A2UI.ComponentRenderer

      use Phoenix.Component

      import A2UI.Components.Renderer,
        only: [
          resolve_prop: 3,
          resolve_prop: 4,
          a11y_attrs: 1,
          binding_path: 1,
          flex_style: 2,
          input_attrs: 2,
          input_attrs: 3,
          resolve_child: 3,
          expand_template_entries: 2,
          render_children: 1,
          component: 1
        ]
    end
  end
end
