# A2UI Elixir — Roadmap

Unimplemented work organized by category. Core protocol layer, data binding,
18 built-in components, LiveView integration, transport, and demo app are
complete. See the codebase and README for current functionality.

---

## Out of Scope

These are not planned for this library:

- **Agent logic** — use GenServer, `langchain`, etc.
- **A2A protocol transport** — use `a2a-elixir` (separate library)
- **Custom component catalogs** — renderers can be extended via
  `A2UI.ComponentRenderer` behaviour, but catalog hosting is not this
  library's concern
