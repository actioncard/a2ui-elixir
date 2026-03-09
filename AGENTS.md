# A2UI Elixir — Project Conventions

## Module Naming

- All modules live under the `A2UI.*` namespace
- No `Impl` suffix — use behaviour modules and concrete implementations directly
- Example: `A2UI.Transport` (behaviour), `A2UI.Transport.Local` (implementation)
- Demo app isolated under `A2UI.Demo.*`

## Code Style

- 100-character line limit
- `@moduledoc`, `@doc`, and `@spec` required on all public functions
- Use `@moduledoc false` for internal modules (never omit the attribute)
- Pipe chains: prefer pipes for 2+ transformations

## Error Handling

- Use `{:ok, value}` / `{:error, reason}` tuples for all business logic
- No `raise` for expected/recoverable errors
- `raise` only for programmer errors (e.g., invalid arguments that indicate a bug)
- Graceful degradation in rendering — use fallback values when bindings fail to resolve

## Testing

- Test file structure mirrors `lib/` structure
- All test modules use `async: true` unless they need shared state
- Shared test builders in `test/support/component_helpers.ex`
- Phoenix component tests use `rendered_to_string/1` + Floki assertions
- `mix test` must pass before committing

## Version Control

- Conventional Commits format: `feat:`, `fix:`, `docs:`, `chore:`, `refactor:`, `test:`
- Keep commits small and focused

## Demo App

- Lives under `dev/demo/` and the `A2UI.Demo.*` namespace
- Not part of the published hex package — dev/test only
- Compiled only in `:dev` and `:test` environments (see `elixirc_paths` in mix.exs)
- Config in `config/config.exs` is demo-specific, not library config
- Run with `mix a2ui.demo`

## Package Info

- Hex package name: `a2ui`
- Version: 0.1.0
- Source: https://github.com/actioncard/a2ui-elixir
- License: Apache-2.0
- Maintainer: Action Card AB

## Architecture

```
Agent (GenServer / A2A Remote Agent)
  │ {:a2ui_message, msg} / PubSub
  ▼
Transport Layer (A2UI.Transport behaviour)
  │
  ▼
LiveView Process (use A2UI.Live)
  ├─ handle_info({:a2ui_message, msg}) → SurfaceManager → assign
  ├─ render: <.surface /> → Renderer walks adjacency list → function components
  ├─ handle_event("a2ui_action") → EventHandler → Transport → agent
  └─ handle_event("a2ui_input_change") → updates local data model
  │
  ▼ LiveView WebSocket
Browser (native HTML, phx-click / phx-change events)
```

## Key Design Decisions

1. **Function Components** (not LiveComponents) — surface state managed centrally in LiveView assigns via SurfaceManager
2. **Pure Functional SurfaceManager** — `apply_message(surfaces, msg) → surfaces`, no GenServer needed
3. **Data Binding Resolved at Render Time** — props stay as raw JSON until render, LiveView diff engine detects changes
4. **Adjacency List Stays Flat** — renderer walks `%{id => component}` map via ID lookups, no tree reconstruction
5. **CSS Convention** — `a2ui-*` BEM-style classes, layout via CSS utility classes, weight via `--a2ui-weight` custom property
6. **Transport as Behaviour** — `A2UI.Transport` behaviour; `Local` (process messages) now, SSE/A2A later

## Do NOT

- Use `Application.get_env/3` in library code — accept config via function arguments
- Add a supervision tree or `mod:` to `application/0`
- Create empty placeholder module files — only create modules when implementing them
- Add `@impl true` on callbacks without a corresponding `@behaviour`
- Put library config in `config/` — that directory is demo-only
