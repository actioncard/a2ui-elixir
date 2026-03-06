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

- Lives under `lib/a2ui/demo/` and the `A2UI.Demo.*` namespace
- Not part of the published library — embedded example only
- Config in `config/config.exs` is demo-specific, not library config
- Run with `mix a2ui.demo`

## Do NOT

- Use `Application.get_env/3` in library code — accept config via function arguments
- Add a supervision tree or `mod:` to `application/0`
- Create empty placeholder module files — only create modules when implementing them
- Add `@impl true` on callbacks without a corresponding `@behaviour`
- Put library config in `config/` — that directory is demo-only
