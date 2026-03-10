# A2UI Elixir — Roadmap

Unimplemented work organized by category. Core protocol layer, data binding,
18 built-in components, LiveView integration, transport, and demo app are
complete. See the codebase and README for current functionality.

---

## Known Gaps

Features defined in the v0.9 spec but not yet implemented:

- **`error` message (client→server)** — v0.9 defines a `ValidationFailed`
  error message (`code`, `surfaceId`, `path`, `message`) that clients send
  back to the agent. Not implemented.
- **`catalogId` validation** — v0.9 expects renderers to validate components
  against a catalog JSON schema referenced by `catalogId` in `createSurface`.
  Components are accepted based on the compile-time registry without remote
  catalog validation.
- **Additional transports** — the spec defines SSE + JSON RPC, REST,
  WebSocket, MCP, and AG-UI transports. Only `Local` (Erlang process
  messages) is implemented. A2A is out of scope (separate `a2a-elixir`
  library).

---

## Out of Scope

These are not planned for this library:

- **Agent logic** — `A2UI.Agent` provides connection/lifecycle scaffolding; business logic uses GenServer, `langchain`, etc.
- **A2A protocol transport** — use `a2a-elixir` (separate library)
- **Custom component catalogs** — renderers can be extended via
  `A2UI.ComponentRenderer` behaviour, but catalog hosting is not this
  library's concern
