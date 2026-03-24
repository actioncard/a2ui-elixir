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

### Running Tests

- **Elixir tests:** `mix test`
- **JS tests:** `mix bun test` (Bun is installed via the `bun` Hex package — do NOT call `bun` directly)
- **All tests:** `mix test.all` (runs both Elixir and JS)
- **CI tests:** `mix test.ci` (Elixir with `--warnings-as-errors` + JS)

### Elixir Test Conventions

- Test file structure mirrors `lib/` structure
- All test modules use `async: true` unless they need shared state
- Shared test builders in `test/support/component_helpers.ex`
- Phoenix component tests use `rendered_to_string/1` + Floki assertions

### JS Test Conventions

- Test files live in `test/js/` and use Bun's built-in test runner (`bun:test`)
- DOM mocks in `test/js/support/dom.js` — use `mockElement`, `mockEvent`, `addChild`
- Hook tests in `test/js/hooks.test.js`, validator tests in `test/js/validators.test.js`
- JS source: `priv/static/a2ui-hooks.js` — exports via CommonJS for test imports

### Pre-commit

- Run `mix precommit` before committing (compile, unlock unused deps, format, test Elixir + JS)

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
- Version: 0.2.0
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
6. **Transport as Behaviour** — `A2UI.Transport` behaviour; `Local` (process messages), `SSE` (HTTP), `A2A` (agent-to-agent)

## Do NOT

- Use `Application.get_env/3` in library code — accept config via function arguments
- Add a supervision tree or `mod:` to `application/0`
- Create empty placeholder module files — only create modules when implementing them
- Add `@impl true` on callbacks without a corresponding `@behaviour`
- Put library config in `config/` — that directory is demo-only
