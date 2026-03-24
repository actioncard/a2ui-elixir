# A2UI

[![Hex.pm](https://img.shields.io/hexpm/v/a2ui.svg)](https://hex.pm/packages/a2ui)
[![Docs](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/a2ui)
[![CI](https://github.com/actioncard/a2ui-elixir/actions/workflows/ci.yml/badge.svg)](https://github.com/actioncard/a2ui-elixir/actions/workflows/ci.yml)
[![License](https://img.shields.io/hexpm/l/a2ui.svg)](LICENSE)
[![AI Assisted](https://img.shields.io/badge/AI-Assisted-blue)](CONTRIBUTING.md)

Elixir implementation of the [A2UI protocol](https://a2ui.org/) — a standard for AI agents to render declarative UI through Phoenix LiveView.

Agents send A2UI v0.9 JSONL messages describing components, and this library renders them as native LiveView function components. User interactions are translated back into A2UI action messages and dispatched to the agent.

> **Pre-release**: This library is under active development. The API may change before 1.0.

> [!NOTE]
> This project is developed with _significant_ AI assistance (Claude, Copilot, etc.)

## Features

- **Protocol parsing** — JSONL stream parser for A2UI v0.9 messages (CreateSurface, UpdateComponents, UpdateDataModel, DeleteSurface, Action)
- **18 component types** — Text, Button, TextField, CheckBox, ChoicePicker, Slider, DateTimeInput, Image, Icon, Divider, Video, AudioPlayer, Row, Column, List, Card, Tabs, Modal
- **Data binding** — two-way binding with JSON Pointer paths, resolved at render time
- **LiveView macro** — `use A2UI.Live` injects mount hook, message handling, and event dispatch
- **Agent macro** — `use A2UI.Agent` handles connection tracking, process monitoring, and message routing
- **Transport abstraction** — `A2UI.Transport` behaviour with built-in local (process message) transport
- **SSE + JSON-RPC transport** — `A2UI.Plug` serves agents over HTTP with Server-Sent Events and JSON-RPC 2.0
- **A2A transport** — `A2UI.A2A` server adapter and `A2UI.Transport.A2A` client for agent-to-agent communication (optional dep on `:a2a`)
- **CSS classes** — BEM-style `a2ui-*` classes on all components for easy styling
- **Demo app** — `mix a2ui.demo` launches a restaurant booking agent at `localhost:4002`

## Quick Start

```elixir
defmodule MyAppWeb.AgentLive do
  use MyAppWeb, :live_view
  use A2UI.Live

  def mount(_params, _session, socket) do
    if connected?(socket) do
      {:ok, transport} = A2UI.Transport.Local.connect(agent: MyApp.Agent)
      {:ok, assign(socket, transport: transport)}
    else
      {:ok, assign(socket, transport: nil)}
    end
  end

  def render(assigns) do
    ~H"""
    <.surface :for={{_id, s} <- @a2ui_surfaces} surface={s} />
    """
  end

  @impl A2UI.Live
  def handle_a2ui_action(action, metadata, socket) do
    A2UI.Transport.Local.send_action(socket.assigns.transport, action, metadata)
    {:noreply, socket}
  end
end
```

On the agent side, `use A2UI.Agent` handles the GenServer boilerplate:

```elixir
defmodule MyApp.Agent do
  use A2UI.Agent

  @impl A2UI.Agent
  def handle_connect(conn, state) do
    A2UI.Agent.send_message(conn, %A2UI.Protocol.Messages.CreateSurface{
      surface_id: "main"
    })
    # send UpdateComponents, UpdateDataModel, etc.
    {:noreply, state}
  end

  @impl A2UI.Agent
  def handle_action(action, _conn, state) do
    IO.inspect(action.name, label: "action")
    {:noreply, state}
  end
end
```

`use A2UI.Live` gives you:

- `@a2ui_surfaces` assign initialized on mount
- Automatic handling of `{:a2ui_message, msg}` info messages
- Automatic handling of `a2ui_action` and `a2ui_input_change` events
- A `handle_a2ui_action/3` callback for dispatching actions to your agent

## Demo

Run the built-in restaurant booking demo:

```bash
mix a2ui.demo
```

Open [http://localhost:4002](http://localhost:4002). The demo shows:

1. A booking form with text input, date picker, slider, and multi-select
2. Two-way data binding — form values update the data model in real time
3. Action dispatch — clicking "Reserve Table" sends an action to the agent
4. Dynamic UI updates — the agent replaces the form with a confirmation screen

## How It Works

A2UI maps naturally to Phoenix LiveView:

| A2UI Concept | Phoenix/LiveView Equivalent |
|---|---|
| Streaming JSONL messages | LiveView WebSocket push to browser |
| Declarative component tree | Phoenix function components + HEEx |
| Data model (JSON document) | LiveView assigns |
| User actions → agent | `phx-click` / `phx-change` events |
| Incremental updates | LiveView diff engine |
| Surface lifecycle | LiveView mount/unmount |

**Message flow:**

1. Agent sends A2UI messages (CreateSurface, UpdateComponents, UpdateDataModel)
2. Transport delivers them as `{:a2ui_message, msg}` to the LiveView process
3. `SurfaceManager` applies messages to update surface state in assigns
4. Renderer walks the component adjacency list from `"root"`, dispatching each type to a function component
5. User interactions trigger `phx-click`/`phx-change` events
6. `EventHandler` builds an A2UI Action message with resolved context bindings
7. `handle_a2ui_action/3` callback dispatches the action back to the agent

## Component Types

| Category | Components |
|---|---|
| **Layout** | Row, Column, List |
| **Display** | Text, Image, Icon, Divider, Video, AudioPlayer |
| **Input** | TextField, CheckBox, ChoicePicker, Slider, DateTimeInput |
| **Container** | Card, Tabs, Modal |
| **Interactive** | Button |

Components use a flat adjacency list — parent-child relationships are ID references, not nesting. This enables incremental streaming and efficient updates by ID.

## Custom Components

Override built-in components or add new types by implementing the `A2UI.ComponentRenderer` behaviour and registering in config.

**Override a built-in:**

```elixir
# config/config.exs
config :a2ui, component_modules: %{
  "Button" => MyApp.A2UI.Button
}
```

**Add a new type:**

```elixir
defmodule MyApp.A2UI.StatusBadge do
  use A2UI.ComponentRenderer

  @impl true
  def render(assigns) do
    status = resolve_prop(assigns.component.props, "status", assigns.ctx, "unknown")
    assigns = assign(assigns, status: status)

    ~H"""
    <span class={"badge badge--#{@status}"}>{@status}</span>
    """
  end
end

# config/config.exs
config :a2ui, component_modules: %{"StatusBadge" => MyApp.A2UI.StatusBadge}
```

Set `use_default_components: false` to replace all built-in components with your own. See the `A2UI.ComponentRenderer` and `A2UI.Components.Renderer` hexdocs for the full assigns contract, available helpers, and configuration details.

## Installation

Add `a2ui` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:a2ui, "~> 0.2.0"}
  ]
end
```

Requires `phoenix_live_view ~> 1.0` and `phoenix_html ~> 4.0` (pulled in as transitive dependencies).

### Static Assets

Copy the JS hooks and CSS to your Phoenix static directory:

```bash
cp deps/a2ui/priv/static/a2ui-hooks.js assets/vendor/
cp deps/a2ui/priv/static/a2ui.css assets/vendor/
```

Then import the hooks in your `app.js`:

```js
import { A2UIHooks } from "../vendor/a2ui-hooks.js"

let liveSocket = new LiveSocket("/live", Socket, {
  hooks: { ...A2UIHooks }
})
```

And import the CSS in your `app.css`:

```css
@import "../vendor/a2ui.css";
```

## Development

```bash
mix deps.get
mix test
mix compile --warnings-as-errors
```

Requires Elixir ~> 1.17.

## How This Differs

a2ui-elixir is a **server-side renderer** — the only one in the A2UI ecosystem as of March 2026. All other implementations (Lit, Angular, React, Flutter) parse A2UI JSON on the client and map to native widgets. This library renders on the server, producing HTML that LiveView ships over WebSocket.

- **v0.9 spec, 18/18 basic catalog components** — full coverage of the current spec
- **Server-side binding + function evaluation** — `formatString`, `formatNumber`, `formatCurrency`, `formatDate`, `pluralize`, and boolean logic resolved on the server; validation functions (`required`, `regex`, `email`, etc.) run client-side via JS hooks
- **No client-side A2UI runtime** — the browser receives plain HTML and minimal JS hooks

## Alternative Implementations

[a2ui_lv](https://github.com/lukaszsamson/a2ui_lv) is another server-side LiveView renderer for A2UI. It takes a similar approach to this library — parsing JSONL messages and rendering Phoenix components — but adds support for both **v0.8 and v0.9** of the protocol and includes A2A protocol extension support.

[ex_a2ui](https://github.com/23min/ex_a2ui) implements the opposite end of the protocol: it is a **protocol server** that encodes A2UI surfaces as JSON and pushes them over WebSocket or SSE to client-side renderers. Where this library and a2ui_lv consume A2UI messages, ex_a2ui produces them.

## Links

- [A2UI Protocol Specification](https://a2ui.org/)
- [A2UI v0.9 Spec](https://a2ui.org/specification/v0.9-a2ui/)
- [Hex Package](https://hex.pm/packages/a2ui)
- [Documentation](https://hexdocs.pm/a2ui)

## License

Apache-2.0 — see [LICENSE](LICENSE).
