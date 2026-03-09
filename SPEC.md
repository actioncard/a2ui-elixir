# A2UI Elixir — Roadmap

Unimplemented work organized by category. Core protocol layer, data binding,
18 built-in components, LiveView integration, transport, and demo app are
complete. See the codebase and README for current functionality.

---

## Components

### Modal Interactivity
Modal overlay renders hidden; no open/dismiss behavior. Add JS hook to toggle
overlay visibility.
- Files: `priv/static/a2ui-hooks.js`, `lib/a2ui/components/modal.ex`
- Ref: [Modal component](https://a2ui.org/reference/components/#modal)

### Image `variant` Prop
Only `fit` is implemented; `variant` (hero/thumbnail) is ignored. Add CSS
classes and apply in Image component.
- Files: `lib/a2ui/components/image.ex`, `priv/static/a2ui.css`
- Ref: [Image component](https://a2ui.org/reference/components/#image)

---

## Rendering

### Theme CSS Variables
`createSurface` theme is stored but not applied to rendering. Apply
`--a2ui-primary` etc. as inline style on `.a2ui-surface` from `surface.theme`.
- File: `lib/a2ui/components/renderer.ex`
- Ref: [createSurface message](https://a2ui.org/reference/messages/#createsurface)

---

## Client-Side Functions

The A2UI v0.9 spec defines named functions registered in the catalog.
Currently all function call descriptors (`%{"call" => ...}`) are passed
through unresolved.

### Input Validation (`checks`)
TextField stores checks as `data-a2ui-checks`, no client-side validation runs.
Implement: `required`, `regex`, `length`, `numeric`, `email`.
- Files: `priv/static/a2ui-hooks.js`, `lib/a2ui/components/text_field.ex`
- Ref: [TextField checks](https://a2ui.org/reference/components/#textfield),
  [Client-side functions](https://a2ui.org/specification/v0.9-a2ui/)

### Formatting Functions
`formatString`, `formatNumber`, `formatCurrency`, `formatDate`, `pluralize`
passed through as raw descriptors. Resolve server-side in `Binding.resolve/3`
or JS-based.
- File: `lib/a2ui/data_model/binding.ex`
- Ref: [Client-side functions](https://a2ui.org/specification/v0.9-a2ui/)

### Boolean Logic Functions
`and`, `or`, `not` passed through as descriptors. Evaluate in
`Binding.resolve/3`.
- File: `lib/a2ui/data_model/binding.ex`
- Ref: [Client-side functions](https://a2ui.org/specification/v0.9-a2ui/)

### Local Actions (`openUrl`)
Button renders `data-a2ui-action` for `functionCall` but no JS handles it.
Add JS to parse and dispatch `openUrl` (and future local actions).
- File: `priv/static/a2ui-hooks.js`
- Ref: [Button action](https://a2ui.org/reference/components/#button)

---

## Out of Scope

These are not planned for this library:

- **Agent logic** — use GenServer, `langchain`, etc.
- **A2A protocol transport** — use `a2a-elixir` (separate library)
- **Custom component catalogs** — renderers can be extended via
  `A2UI.ComponentRenderer` behaviour, but catalog hosting is not this
  library's concern
