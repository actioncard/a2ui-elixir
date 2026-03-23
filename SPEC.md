# A2UI Elixir — Roadmap

Core protocol layer, data binding, 18 built-in components, LiveView
integration, Local transport, and demo app are complete. See the codebase and
README for current functionality.

This document is the implementation plan for remaining work — organized as
independent phases that can be built and shipped incrementally.

---

## Architecture: Network Transports

The A2UI v0.9 spec is transport-agnostic. It defines the JSON envelope format
and message semantics but does not prescribe specific transport bindings. The
spec lists these as viable options:

| Transport      | Type             | Status                                    |
|----------------|------------------|-------------------------------------------|
| Local          | Erlang messages  | **Done** (`A2UI.Transport.Local`)         |
| SSE + JSON-RPC | HTTP transport   | **Done** (`A2UI.Plug`, `A2UI.Plug.SSE`, `A2UI.Plug.JSONRPC`) |
| A2A            | Protocol adapter | Phase 2                                   |
| WebSocket      | HTTP transport   | Phase 3                                   |
| REST           | HTTP transport   | Phase 4                                   |
| AG-UI          | Protocol adapter | Phase 5                                   |
| MCP            | Protocol adapter | Phase 6 (future — spec needs more detail) |

### Connection Abstraction

`A2UI.Connection` is an opaque handle representing a connected client. The
agent receives it in `handle_connect/2` and passes it to `send_message/2` —
the agent never knows which transport is in use.

```
External Client ←──HTTP/WS──→ Handler Process ←──Erlang msgs──→ A2UI Agent
                               (A2UI.Connection)
```

- `A2UI.Connection` struct: `id`, `transport` (module), `ref`, `pid`
- `A2UI.Agent.send_message/2` dispatches through `transport.deliver_message(ref, msg)`
- `A2UI.Transport` behaviour includes `deliver_message/2` (agent→client direction)
- Agent tracks connections as `%{id => Connection.t()}` with `Process.monitor`
- Dispatch helpers: `A2UI.Transport.send_action/3`, `.send_error/3`, `.disconnect/1`

### Transport Contract (from v0.9 spec)

All transports must fulfill:
1. **Reliable, ordered delivery** — messages arrive in generation order
2. **Message framing** — clear boundaries between JSON envelopes (newline-delimited JSON, SSE events, or WebSocket frames)
3. **Metadata support** — data model sync (`a2uiClientDataModel`) and capabilities exchange (`a2uiClientCapabilities`)
4. **Bidirectional capability** (optional) — return channel for `action` messages

---

## Phase 1: SSE + JSON-RPC Transport

> Primary network transport for web clients. Server→client via SSE stream,
> client→server via JSON-RPC 2.0 POST.

### Modules

- [x] **`A2UI.Plug`** — Plug router, guarded with `Code.ensure_loaded?(Plug)`
  - `GET /sse` → SSE connection endpoint
  - `POST /rpc` → JSON-RPC endpoint
  - Options: `:agent` (required), `:sse_path`, `:rpc_path`

- [x] **`A2UI.Plug.SSE`** — SSE connection handler
  - On GET: generate unique connection ID, create `A2UI.Connection`
  - Connects to agent via `{:a2ui_connect, %Connection{}}`
  - Receives `{:a2ui_deliver, msg}` → `Message.to_json/1` → SSE `data:` event
  - SSE event format: `id: <seq>\ndata: <json>\n\n`
  - Keep-alive pings every 30s
  - Initial SSE event includes `connectionId` for client to use in JSON-RPC

- [x] **`A2UI.Plug.JSONRPC`** — JSON-RPC request handler
  - Method `a2ui.action`: params `{connectionId, action}` → parse Action → forward to agent via handler pid
  - Method `a2ui.error`: params `{connectionId, error}` → parse Error → forward to agent via handler pid
  - Returns JSON-RPC 2.0 success/error responses
  - Looks up handler pid from connection registry

- [x] **`A2UI.Plug.ConnectionRegistry`** — ETS-based registry
  - Maps `connection_id → handler_pid`
  - Created lazily in `A2UI.Plug.init/1`
  - Auto-cleanup when handler process exits (via monitor)

### Wire Format

Server→client (SSE events):
```
id: 1
data: {"version":"v0.9","createSurface":{"surfaceId":"main","catalogId":"basic"}}

id: 2
data: {"version":"v0.9","updateComponents":{"surfaceId":"main","components":[...]}}
```

Client→server (JSON-RPC POST):
```json
{"jsonrpc":"2.0","method":"a2ui.action","params":{"connectionId":"abc123","action":{"name":"submit","surfaceId":"main","sourceComponentId":"btn1","timestamp":"2025-01-01T00:00:00Z","context":{}}},"id":1}
```

### Dependencies

No new required deps. Plug is already transitive via `phoenix_live_view`.

### Tests

- `test/a2ui/plug/sse_test.exs` — start agent, open SSE, verify events stream
- `test/a2ui/plug/json_rpc_test.exs` — POST actions, verify JSON-RPC responses
- `test/a2ui/plug_test.exs` — routing, 404s, method not allowed

---

## Phase 2: A2A Transport Binding

> Uses the A2A (Agent-to-Agent) protocol as transport between a LiveView
> renderer and a remote A2UI agent. Enables the core agentic use case:
> AI agents rendering UI across process or network boundaries.

The v0.9 spec defines A2A as a first-class transport binding:
- Each A2UI envelope maps to a single `A2A.Part.Data` in an A2A message
- `a2uiClientDataModel` placed in A2A message `metadata` when `sendDataModel` is active
- `a2uiClientCapabilities` placed in `metadata` of every client→server message
- A2UI sessions map to A2A `contextId`

### Client Side — `A2UI.Transport.A2A`

Implements the `A2UI.Transport` behaviour. Allows a LiveView to connect
to a remote A2UI agent over A2A protocol (HTTP JSON-RPC + SSE streaming).

- [ ] **`A2UI.Transport.A2A`** — A2A client transport
  - `connect/1` — accepts `:url` (agent card URL) or `:client` (pre-built `A2A.Client`),
    discovers agent card, sends initial A2A message with `a2uiClientCapabilities` in metadata
  - Spawns a handler process that calls `A2A.Client.stream_message/2`
  - Extracts A2UI envelopes from `A2A.Part.Data` parts in the response stream
  - Delivers each as `{:a2ui_message, parsed_struct}` to the LiveView
  - `send_action/3` — sends A2A message with Action as `Part.Data`, includes
    `a2uiClientDataModel` in metadata when `send_data_model` is active
  - `send_error/3` — sends A2A message with Error as `Part.Data`
  - `disconnect/1` — cancels the A2A task if still running
  - Manages A2A task lifecycle: uses `contextId` for session continuity,
    continues tasks via `task_id` on `input_required` state

### Server Side — `A2UI.A2A`

Wraps an `A2UI.Agent` so it can be served over A2A protocol. An A2A client
(including `A2UI.Transport.A2A` above) can connect to it.

- [ ] **`A2UI.A2A`** — adapter macro
  - `use A2UI.A2A, agent: MyApp.UIAgent` generates an `A2A.Agent` that
    wraps the given `A2UI.Agent`
  - On `handle_message/2`: extracts A2UI actions/errors from incoming
    `Part.Data` parts → creates `A2UI.Connection` → forwards to the A2UI agent
  - Collects `{:a2ui_message, msg}` responses from the agent →
    wraps each as `A2A.Part.Data` with the A2UI JSON envelope
  - Returns `{:stream, enumerable}` for real-time message delivery or
    `{:reply, parts}` for batch response
  - Maps A2A `contextId` to A2UI connection/session for multi-turn interactions
  - First message in a context triggers `handle_connect`; subsequent messages
    with the same `contextId` route to `handle_action`

### A2A ↔ A2UI Message Mapping

```
A2A Message (client → server)              A2UI Message
─────────────────────────────              ─────────────
Part.Data with action JSON        →        Action struct
Part.Data with error JSON         →        Error struct
metadata.a2uiClientDataModel      →        data model sync
metadata.a2uiClientCapabilities   →        capabilities exchange
contextId                         →        session/connection ID

A2A Message (server → client)              A2UI Message
─────────────────────────────              ─────────────
Part.Data with createSurface      ←        CreateSurface
Part.Data with updateComponents   ←        UpdateComponents
Part.Data with updateDataModel    ←        UpdateDataModel
Part.Data with deleteSurface      ←        DeleteSurface
```

### Wire Format

A2UI envelope embedded as A2A Data part:
```json
{
  "role": "ROLE_AGENT",
  "parts": [
    {"kind": "data", "data": {"version":"v0.9","createSurface":{"surfaceId":"main","catalogId":"basic"}}}
  ],
  "metadata": {}
}
```

Client action sent as A2A message:
```json
{
  "role": "ROLE_USER",
  "parts": [
    {"kind": "data", "data": {"name":"submit","surfaceId":"main","sourceComponentId":"btn1","timestamp":"...","context":{}}}
  ],
  "metadata": {
    "a2uiClientCapabilities": {"supportedCatalogIds": ["https://a2ui.org/specification/v0_9/basic_catalog.json"]},
    "a2uiClientDataModel": {"surfaces": {"main": {"reservation": {"name": "Alice"}}}}
  }
}
```

### Dependencies

- `{:a2a, "~> 0.1"}` — optional dependency, guarded with `Code.ensure_loaded?(A2A.Agent)`

### Tests

- `test/a2ui/transport/a2a_test.exs` — client transport: connect, receive messages, send actions
- `test/a2ui/a2a_test.exs` — server adapter: A2A message → A2UI agent → A2A response

---

## Phase 3: WebSocket Transport (was Phase 2)

> Full-duplex communication over a single WebSocket connection. Simpler than
> SSE + JSON-RPC since both directions use the same connection.

### Modules

- [ ] **`A2UI.Plug.WebSocket`** — `WebSock` behaviour handler
  - On upgrade: generate connection ID, connect to agent via `{:a2ui_connect, self()}`
  - Receives WS text frame → `Message.from_json/1` → forward to agent as `{:a2ui_action, action, metadata}` or `{:a2ui_error, error, metadata}`
  - Receives `{:a2ui_message, msg}` → `Message.to_json/1` → send as WS text frame
  - On WS close: `{:a2ui_disconnect, self()}`

### Wire Format

Both directions use the same JSON envelope format as the protocol spec:
```json
{"version":"v0.9","updateComponents":{"surfaceId":"main","components":[...]}}
```
```json
{"name":"submit","surfaceId":"main","sourceComponentId":"btn1","timestamp":"...","context":{}}
```

### Dependencies

- `{:websock, "~> 0.5", optional: true}` — or rely on it being available via Bandit/Phoenix

### Tests

- `test/a2ui/plug/websocket_test.exs` — start Bandit, connect WS client, verify bidirectional messages

---

## Phase 4: REST Transport (was Phase 3)

> Stateless HTTP for simple integrations, webhooks, and non-streaming clients.

### Modules

- [ ] **`A2UI.Plug.REST`** — stateless HTTP handler
  - `POST /action` — receive Action JSON, return response messages as JSON array
  - Implementation: spawn temporary proxy process → connect to agent → send action → collect response messages (with configurable timeout) → disconnect → return
  - `POST /connect` — optional: create surface, return initial messages
  - `POST /disconnect` — optional: clean up

### Limitations

- No streaming — client gets a batch of response messages, not a live stream
- Timing-dependent: proxy process waits for a configurable window (e.g. 100ms) to collect agent responses
- Not suitable for long-running agent interactions
- Good for: webhooks, simple form submissions, testing, one-shot queries

### Tests

- `test/a2ui/plug/rest_test.exs` — POST action, verify response contains expected messages

---

## Phase 5: AG-UI Protocol Adapter (was Phase 4)

> Maps A2UI protocol to CopilotKit's AG-UI event-based protocol. Enables A2UI
> agents to serve AG-UI compatible frontends.

AG-UI uses a single `POST /` endpoint. The client sends `RunAgentInput` JSON,
the server responds with an SSE stream of typed events. AG-UI defines 16 event
types organized into lifecycle, text, tool, state, and custom categories.

### Modules

- [ ] **`A2UI.AGUI.Plug`** — AG-UI endpoint
  - `POST /` — receives `RunAgentInput`, starts SSE event stream
  - Spawns handler process (proxy pid) → connects to agent
  - Wraps A2UI message flow in AG-UI lifecycle: `RUN_STARTED` → events → `RUN_FINISHED`

- [ ] **`A2UI.AGUI.EventMapper`** — A2UI → AG-UI event translation
  - `CreateSurface` → `STATE_SNAPSHOT` (surface as initial state)
  - `UpdateComponents` → `STATE_DELTA` (RFC 6902 JSON Patch for component changes)
  - `UpdateDataModel` → `STATE_DELTA` (JSON Patch for data model changes)
  - `DeleteSurface` → `STATE_DELTA` (remove surface key)
  - Custom events for A2UI-specific semantics that don't map cleanly

- [ ] **`A2UI.AGUI.InputMapper`** — AG-UI → A2UI input translation
  - `RunAgentInput.messages` → A2UI `Action` messages
  - `RunAgentInput.state` → A2UI data model (surface state sync)
  - `RunAgentInput.tools` → A2UI capabilities metadata

- [ ] **`A2UI.AGUI.Encoder`** — SSE event encoding
  - Encodes AG-UI events as SSE: `event: <type>\ndata: <json>\n\n`
  - Event types: `RUN_STARTED`, `RUN_FINISHED`, `RUN_ERROR`, `STATE_SNAPSHOT`, `STATE_DELTA`, `CUSTOM`, etc.

### AG-UI Event Mapping Detail

```
A2UI Agent Flow                    AG-UI Event Stream
──────────────                     ──────────────────
connect                         → RUN_STARTED {threadId, runId}
CreateSurface{surfaceId, ...}   → STATE_SNAPSHOT {snapshot: {surfaces: {<id>: ...}}}
UpdateComponents{surfaceId, ..} → STATE_DELTA {delta: [{op:"replace", path:"/surfaces/<id>/components", value:...}]}
UpdateDataModel{surfaceId, ..}  → STATE_DELTA {delta: [{op:"replace", path:"/surfaces/<id>/dataModel/<path>", value:...}]}
DeleteSurface{surfaceId}        → STATE_DELTA {delta: [{op:"remove", path:"/surfaces/<id>"}]}
disconnect                      → RUN_FINISHED {threadId, runId}
error                           → RUN_ERROR {message, code}
```

### Wire Format

Request:
```json
POST /
Content-Type: application/json
Accept: text/event-stream

{"threadId":"t1","runId":"r1","state":{},"messages":[{"id":"m1","role":"user","content":"..."}],"tools":[],"context":[],"forwardedProps":{}}
```

Response (SSE):
```
event: RUN_STARTED
data: {"type":"RUN_STARTED","threadId":"t1","runId":"r1"}

event: STATE_SNAPSHOT
data: {"type":"STATE_SNAPSHOT","snapshot":{"surfaces":{"main":{"catalogId":"basic","components":{},"dataModel":{}}}}}

event: STATE_DELTA
data: {"type":"STATE_DELTA","delta":[{"op":"replace","path":"/surfaces/main/components","value":{...}}]}

event: RUN_FINISHED
data: {"type":"RUN_FINISHED","threadId":"t1","runId":"r1"}
```

### Dependencies

No external deps — AG-UI is SSE-based, uses the same Plug chunked response
pattern as Phase 1. No Elixir AG-UI SDK exists, so we implement from spec.

### Tests

- `test/a2ui/agui/event_mapper_test.exs` — unit tests for A2UI → AG-UI mapping
- `test/a2ui/agui/input_mapper_test.exs` — unit tests for AG-UI → A2UI mapping
- `test/a2ui/agui/plug_test.exs` — integration: POST RunAgentInput, verify SSE events

---

## Phase 6: MCP Adapter (Future, was Phase 5)

> Map A2UI to Model Context Protocol for AI agents that use MCP tool calls.

The v0.9 spec mentions MCP as "delivered as tool outputs or resource
subscriptions" but provides no detailed binding. This phase is deferred until
the spec provides more guidance.

### Likely Shape

- Separate package: `a2ui_mcp`
- A2UI messages as MCP tool results with structured content
- MCP tool calls → A2UI actions
- MCP resource subscriptions → A2UI surface streams
- Depends on an MCP Elixir library (e.g. `mcp`)

---

## Out of Scope

These are not planned for this library:

- **Agent logic** — `A2UI.Agent` provides connection/lifecycle scaffolding;
  business logic uses GenServer, `langchain`, etc.
- **Custom component catalogs** — renderers can be extended via
  `A2UI.ComponentRenderer` behaviour, but catalog hosting is not this
  library's concern
