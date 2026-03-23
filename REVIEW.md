# Review Exclusions

Files and paths that automated reviewers should skip.

## Skip these files

- `mix.lock` — dependency lock file, not human-authored
- `priv/plts/` — Dialyzer PLT cache (generated)
- `priv/static/a2ui.css` — generated CSS bundle
- `.formatter.exs` — formatter config, rarely meaningful to review
- `.github/workflows/` — CI configs, reviewed manually
- `config/` — demo-only config, not part of the library

## Skip these patterns

- Documentation-only changes (`*.md` files, `@moduledoc`/`@doc` edits)
- Dependency version bumps with no code changes
- Test fixture data files
