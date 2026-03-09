# A2UI for Phoenix/LiveView - Specification

## Overview

This library implements an [A2UI](https://a2ui.org/) renderer for Phoenix/LiveView. A2UI (Agent to UI) is Google's open protocol for agent-driven interfaces - AI agents send declarative JSON describing UI components, and client renderers map these to native widgets.

Phoenix LiveView acts as the **renderer**: it receives A2UI v0.9 JSONL messages from agents and renders them as native LiveView function components in the browser. User interactions are translated back into A2UI action messages and dispatched to the agent.

### Why Phoenix LiveView?

| A2UI Concept | Phoenix/LiveView Equivalent |
|---|---|
| Streaming JSONL messages | LiveView WebSocket push to browser |
| Declarative component tree | Phoenix function components + HEEx |
| Data model (JSON document) | LiveView assigns |
| User actions → agent | `phx-click` / `phx-change` events |
| Incremental updates | LiveView diff engine |
| Surface lifecycle | LiveView mount/unmount |

## A2UI Protocol Summary (v0.9)

### Message Types (Server → Client)

All messages include `"version": "v0.9"`.

#### createSurface

Creates a new rendering surface with a catalog reference.

```json
{
  "version": "v0.9",
  "createSurface": {
    "surfaceId": "main",
    "catalogId": "https://a2ui.org/specification/v0_9/basic_catalog.json",
    "theme": {
      "primaryColor": "#1a73e8",
      "iconUrl": "https://example.com/icon.png",
      "agentDisplayName": "My Agent"
    },
    "sendDataModel": true
  }
}
```

| Field | Type | Required | Description |
|---|---|---|---|
| `surfaceId` | string | yes | Unique surface identifier |
| `catalogId` | string | yes | URL/ID of the component catalog |
| `theme` | object | no | Theme with `primaryColor`, `iconUrl`, `agentDisplayName` |
| `sendDataModel` | boolean | no | If true, client sends full data model with every action |

#### updateComponents

Adds or updates components in a surface. Components are a flat adjacency list - parent-child relationships use ID references.

```json
{
  "version": "v0.9",
  "updateComponents": {
    "surfaceId": "main",
    "components": [
      {
        "id": "root",
        "component": "Column",
        "children": ["header", "form-card"],
        "align": "stretch"
      },
      {
        "id": "header",
        "component": "Text",
        "text": "# Book Your Table",
        "variant": "h1"
      },
      {
        "id": "form-card",
        "component": "Card",
        "child": "form-column"
      },
      {
        "id": "form-column",
        "component": "Column",
        "children": ["date-picker", "submit-row"]
      },
      {
        "id": "date-picker",
        "component": "DateTimeInput",
        "label": "Select Date",
        "value": {"path": "/reservation/date"},
        "enableDate": true
      },
      {
        "id": "submit-text",
        "component": "Text",
        "text": "Confirm Reservation"
      },
      {
        "id": "submit-row",
        "component": "Row",
        "children": ["submit-btn"],
        "justify": "end"
      },
      {
        "id": "submit-btn",
        "component": "Button",
        "child": "submit-text",
        "variant": "primary",
        "action": {"event": {"name": "confirm_booking"}}
      }
    ]
  }
}
```

| Field | Type | Required | Description |
|---|---|---|---|
| `surfaceId` | string | yes | Target surface |
| `components` | array | yes | Flat list of component objects |

Each component object:

| Field | Type | Required | Description |
|---|---|---|---|
| `id` | string | yes | Unique within surface. `"root"` is the tree root. |
| `component` | string | yes | Component type name from catalog |
| *(other)* | varies | no | Component-specific properties |

Sending a component with an existing ID replaces/updates that component.

#### updateDataModel

Updates the surface's data model at a JSON Pointer path.

```json
{
  "version": "v0.9",
  "updateDataModel": {
    "surfaceId": "main",
    "path": "/reservation",
    "value": {
      "date": "2025-12-15",
      "time": "19:00",
      "guests": 2
    }
  }
}
```

| Field | Type | Required | Description |
|---|---|---|---|
| `surfaceId` | string | yes | Target surface |
| `path` | string | no | JSON Pointer path (default `"/"` = root) |
| `value` | any | no | Value to set. Omit to delete at path. |

#### deleteSurface

Removes a surface and all associated state.

```json
{
  "version": "v0.9",
  "deleteSurface": {
    "surfaceId": "main"
  }
}
```

### Message Types (Client → Server)

#### action

Sent when a user interacts with a component that has an action defined.

```json
{
  "name": "confirm_booking",
  "surfaceId": "main",
  "sourceComponentId": "submit-btn",
  "timestamp": "2025-12-15T10:30:00Z",
  "context": {
    "date": "2025-12-15",
    "time": "19:00"
  }
}
```

| Field | Type | Description |
|---|---|---|
| `name` | string | Action name from the component's action definition |
| `surfaceId` | string | Surface where the action originated |
| `sourceComponentId` | string | Component that triggered the action |
| `timestamp` | string | ISO 8601 timestamp |
| `context` | object | Resolved key-value pairs from the action's context bindings |

### Component Model: Adjacency List

Components are a **flat list** with ID-based references instead of nested trees:

```
root (Column) → children: ["header", "list"]
header (Text)
list (List) → children: template {componentId: "item", path: "/items"}
item (Card) → child: "item-text"
item-text (Text) → text: {path: "name"}  (relative path, resolved per template item)
```

This design enables:
- Incremental streaming (send components as they're generated)
- Efficient updates (replace by ID without tree traversal)
- LLM-friendly (flat structure, no nesting to track)

### Children Patterns

**Single child** (Button, Card):
```json
"child": "child-component-id"
```

**Static children** (Row, Column, List):
```json
"children": ["child-1", "child-2", "child-3"]
```

**Template children** (List - dynamic rendering from data):
```json
"children": {
  "template": {
    "componentId": "item-template",
    "path": "/items"
  }
}
```

The template renders the `componentId` once per item in the data array at `path`. Inside template components, data binding paths are **relative** to the current item (e.g., `"name"` resolves to `/items/0/name`, `/items/1/name`, etc.).

### Data Binding

Component properties can be either literal values or data-bound:

**Literal**: `"text": "Hello World"`

**Data-bound**: `"value": {"path": "/user/name"}`

**Path resolution**:
- Absolute paths start with `/`: `"/user/name"` → resolved from data model root
- Relative paths (no `/`): `"name"` → resolved from current template scope's base path

**Two-way binding** (input components):
- **Read**: Component displays value from bound path
- **Write**: User input immediately updates the local data model
- **Sync**: Server receives updated state only when an action triggers (e.g., button click with `sendDataModel: true`)

### Actions

**Server actions** (sent to agent):
```json
"action": {
  "event": {
    "name": "submit_form",
    "context": {
      "date": {"path": "/reservation/date"},
      "guests": {"path": "/reservation/guests"}
    }
  }
}
```

Context values are resolved (data bindings evaluated) before sending to the agent.

**Local actions** (handled client-side):
```json
"action": {
  "functionCall": {
    "call": "openUrl",
    "args": {"url": "https://example.com"}
  }
}
```

### Basic Catalog Components

#### Layout

| Component | Properties | Children |
|---|---|---|
| **Row** | `justify` (start/center/end/spaceBetween/spaceAround/spaceEvenly), `align` (start/center/end/stretch) | `children`: array or template |
| **Column** | `justify`, `align` (same as Row) | `children`: array or template |
| **List** | `direction` (vertical/horizontal), `align` | `children`: array or template |

#### Display

| Component | Properties |
|---|---|
| **Text** | `text` (string or binding), `variant` (h1/h2/h3/h4/h5/body/caption) |
| **Image** | `url` (string or binding), `fit` (cover/contain/fill/etc), `variant` (hero/thumbnail/etc) |
| **Icon** | `name` (string or binding - from standard icon set) |
| **Divider** | `axis` (horizontal/vertical) |
| **Video** | `url`, `autoplay`, `controls` |
| **AudioPlayer** | `url`, `controls` |

#### Interactive

| Component | Properties |
|---|---|
| **Button** | `child` (component ID), `variant` (primary/default/borderless), `action` |
| **TextField** | `label`, `value` (binding), `textFieldType` (shortText/longText/number/obscured), `checks` (validation) |
| **CheckBox** | `label`, `value` (binding, boolean) |
| **ChoicePicker** | `options` ([{label, value}]), `selections` (binding), `maxAllowedSelections` |
| **Slider** | `value` (binding), `minValue`, `maxValue` |
| **DateTimeInput** | `value` (binding), `enableDate`, `enableTime` |

#### Container

| Component | Properties | Children |
|---|---|---|
| **Card** | *(none specific)* | `child`: single component ID |
| **Tabs** | `tabItems`: [{title, child}] | Referenced by tabItems |
| **Modal** | *(none specific)* | `entryPointChild`, `contentChild`: component IDs |

#### Universal Properties

All components support:
- `id` (required, unique within surface)
- `accessibility` ({label, role})
- `weight` (number, flex-grow factor)

### Client-Side Functions (v0.9)

Named functions registered in the catalog (no executable code sent):

**Validation**: `required`, `regex`, `length`, `numeric`, `email`
**Formatting**: `formatString`, `formatNumber`, `formatCurrency`, `formatDate`, `pluralize`
**Logic**: `and`, `or`, `not`
**Actions**: `openUrl`

Input components define `checks` array:
```json
"checks": [
  {"call": "required", "message": "This field is required"},
  {"call": "email", "message": "Please enter a valid email"}
]
```

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│ Agent (GenServer / A2A Remote Agent)                     │
│  Generates A2UI v0.9 JSONL messages                     │
└──────────────────────┬──────────────────────────────────┘
                       │ {:a2ui_message, msg} / PubSub
                       ▼
┌─────────────────────────────────────────────────────────┐
│ Transport Layer (A2UI.Transport behaviour)               │
│  Local: PubSub / process messages                       │
│  Future: SSE, A2A (via a2a-elixir)                      │
└──────────────────────┬──────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────┐
│ LiveView Process (use A2UI.Live)                        │
│                                                         │
│  handle_info({:a2ui_message, msg})                      │
│    → SurfaceManager.apply_message(surfaces, msg)        │
│    → assign(socket, :a2ui_surfaces, updated)            │
│                                                         │
│  render:                                                │
│    <.surface surface={@a2ui_surfaces["main"]} />        │
│    → Renderer walks adjacency list from "root"          │
│    → Dispatches each component type to function comp    │
│    → Resolves data bindings at render time               │
│                                                         │
│  handle_event("a2ui_action", params)                    │
│    → EventHandler builds Action message                 │
│    → Dispatches via handle_a2ui_action/3 callback       │
│    → Transport sends to agent                           │
│                                                         │
│  handle_event("a2ui_input_change", params)              │
│    → Updates local data model (two-way binding)         │
└─────────────────────────────────────────────────────────┘
                       │
                       ▼ LiveView WebSocket
┌─────────────────────────────────────────────────────────┐
│ Browser                                                 │
│  Native HTML rendered by LiveView                       │
│  phx-click / phx-change events for interactions         │
└─────────────────────────────────────────────────────────┘
```

## Project Structure

```
a2ui/
  mix.exs
  lib/
    a2ui.ex                              # Public API facade

    a2ui/
      # ── Protocol Layer (no Phoenix dependency) ──
      protocol/
        message.ex                       # Union type + from_json/1 pattern-match dispatcher
        parser.ex                        # JSONL stream → message structs (single + streaming)
        messages/
          create_surface.ex              # %CreateSurface{}
          update_components.ex           # %UpdateComponents{}
          update_data_model.ex           # %UpdateDataModel{}
          delete_surface.ex              # %DeleteSurface{}
          action.ex                      # %Action{} (client → server)

      # ── Core Data Structures ──
      surface.ex                         # %Surface{id, catalog_id, theme, components, data_model, ...}
      component.ex                       # %Component{id, type, props, accessibility}
      component_tree.ex                  # Adjacency list ops: root/1, child_ids/1, expand_template/3
      data_model.ex                      # JSON document store: get/set/delete via JSON Pointer
      data_model/
        json_pointer.ex                  # RFC 6901: parse, resolve, escape/unescape
        binding.ex                       # Dynamic value resolution (literal, path, function call)

      # ── State Management ──
      surface_manager.ex                 # Pure functions: apply_message(surfaces, msg) → surfaces

      # ── Transport ──
      transport.ex                       # Behaviour: connect/1, send_action/3, disconnect/1
      transport/
        local.ex                         # Process messaging transport

      # ── Phoenix/LiveView Integration ──
      live.ex                            # `use A2UI.Live` macro + behaviour
      live/
        event_handler.ex                 # phx-* events → A2UI action messages
        init_hook.ex                     # on_mount hook: initializes @a2ui_surfaces

      # ── Function Components ──
      component_renderer.ex              # Behaviour for custom component renderers
      components/
        render_context.ex                # RenderContext struct (components, data_model, surface_id, scope_path)
        renderer.ex                      # Entry point: surface/1, component/1 + type dispatch
        text.ex
        button.ex
        image.ex
        icon.ex
        divider.ex
        row.ex
        column.ex
        list_component.ex
        card.ex
        tabs.ex
        modal.ex
        text_field.ex
        check_box.ex
        choice_picker.ex
        slider.ex
        date_time_input.ex
        video.ex
        audio_player.ex

  # ── Demo Application (dev/test only, not published) ──
  dev/
    demo/
      a2ui/demo/
        agent.ex                         # Demo agent GenServer
        demo_live.ex                     # Demo LiveView page
        endpoint.ex                      # Phoenix Endpoint for demo
        error_html.ex                    # Error page template
        layouts.ex                       # Layout components
        router.ex                        # Demo routes
        status_badge.ex                  # Custom component example
      mix/tasks/
        a2ui.demo.ex                     # Mix task to run the demo

  test/
    test_helper.exs
    a2ui/
      protocol/
        parser_test.exs
        messages_test.exs
      data_model_test.exs
      data_model/
        json_pointer_test.exs
        binding_test.exs
      component_tree_test.exs
      surface_manager_test.exs
      live_test.exs
      components/
        renderer_test.exs
        text_test.exs
        button_test.exs
        display_test.exs
        input_test.exs
        layout_test.exs
        container_test.exs
        media_test.exs
      live/
        event_handler_test.exs
      transport/
        local_test.exs
      demo/
        agent_test.exs
    support/
      component_helpers.ex               # Test builders: make_component, make_ctx, make_surface
      fixtures/                          # JSON fixtures from A2UI spec
```

## Key Design Decisions

### 1. Function Components (not LiveComponents)

A2UI surface state is managed centrally in LiveView assigns via `SurfaceManager`. Each component receives resolved props and renders HEEx. This is simpler than LiveComponents (which have their own state lifecycle), and lets LiveView's diffing engine handle update efficiency.

### 2. Pure Functional SurfaceManager

No GenServer needed for the common case. Surfaces live in LiveView assigns as `%{surface_id => %Surface{}}`. The `SurfaceManager` module is pure functions: `apply_message(surfaces, msg) → surfaces`. A GenServer wrapper can be added later for shared state across processes.

### 3. Data Binding Resolved at Render Time

Component props stay as raw JSON (with `{"path": "..."}` maps) until render. The function component resolves bindings when it renders. This means LiveView's diff engine naturally detects when resolved values change.

### 4. Adjacency List Stays Flat

No tree reconstruction. The renderer walks the flat `%{id => component}` map via ID lookups. Container components call `Renderer.component/1` recursively for their children. This matches A2UI's design philosophy exactly.

### 5. CSS Convention

Components render with `a2ui-*` BEM-style CSS classes (e.g. `a2ui-text--h1`, `a2ui-button--primary`). Layout uses CSS utility classes (e.g. `a2ui-justify-center`, `a2ui-align-stretch`) generated by `Renderer.layout_classes/1`. Weight uses a CSS custom property `--a2ui-weight` via `Renderer.weight_style/1`. All styles are defined in `priv/static/a2ui.css`. Users can override styling via their own CSS or configure a custom class mapping.

### 6. Transport as Behaviour

Transport is abstracted behind `A2UI.Transport` behaviour. Initial implementation is `Local` (process messages / PubSub). Future implementations: SSE/HTTP, A2A protocol (via `a2a-elixir`).

## Dependencies

```elixir
defp deps do
  [
    # Required
    {:jason, "~> 1.4"},
    {:phoenix_live_view, "~> 1.0"},
    {:phoenix_html, "~> 4.0"},

    # Dev/Test
    {:floki, "~> 0.36", only: :test},
    {:ex_doc, "~> 0.34", only: :dev, runtime: false},
    {:bandit, "~> 1.0", only: :dev},
    {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
    {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
  ]
end
```

## Implementation Phases

### Completed

- **Phase 1**: Core Protocol + Data Structures (JSON Pointer, DataModel, Component, Surface, message structs, JSONL parser)
- **Phase 2**: State Management + Data Binding (Binding resolution, ComponentTree, SurfaceManager)
- **Phase 3**: Phoenix Components + Renderer (18 built-in components, type dispatch, Floki tests)
- **Phase 4**: LiveView Integration + Events (EventHandler, `use A2UI.Live` macro, Transport behaviour, Transport.Local)
- **Demo**: Demo application with agent, LiveView page, custom StatusBadge component
- **Phase 5**: Video & AudioPlayer components (complete basic catalog coverage)
- **Phase 6**: Extract Shared Component Helpers (`input_attrs/2,3`, `resolve_child/3`, `expand_template_entries/2` into Renderer)
- **Phase 7**: Remove dead code (`A2UI.Components` module) + rename `live_component_fn/1` → `dispatch_render/1`
- **Phase 8+9**: CSS Class Cleanup + Styling Overhaul (replaced all inline styles with CSS classes, `flex_style/2` → `layout_classes/1` + `weight_style/1`, image fit/tabs/modal visibility via classes)
- **Phase 10**: Isolate Demo from Package (moved demo files to `dev/demo/`, env-specific config, demo excluded from hex package)

## Example Usage

```elixir
# In your LiveView
defmodule MyAppWeb.AgentLive do
  use MyAppWeb, :live_view
  use A2UI.Live

  def mount(_params, _session, socket) do
    # Connect to local agent
    {:ok, transport} = A2UI.Transport.Local.connect(agent: MyApp.Agent)
    {:ok, assign(socket, transport: transport)}
  end

  def render(assigns) do
    ~H"""
    <div class="agent-ui">
      <.surface :for={{_id, surface} <- @a2ui_surfaces} surface={surface} />
    </div>
    """
  end

  # Override to dispatch actions to agent
  def handle_a2ui_action(action, metadata, socket) do
    A2UI.Transport.Local.send_action(socket.assigns.transport, action, metadata)
    {:noreply, socket}
  end
end
```

## References

- [A2UI Protocol](https://a2ui.org/)
- [A2UI v0.9 Specification](https://a2ui.org/specification/v0.9-a2ui/)
- [A2UI GitHub](https://github.com/google/A2UI)
- [A2UI Component Gallery](https://a2ui.org/reference/components/)
- [A2UI Message Reference](https://a2ui.org/reference/messages/)
- [A2UI Agent Development Guide](https://a2ui.org/guides/agent-development/)
