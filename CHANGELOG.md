# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2026-03-24

### Added

- `A2UI.Agent` behaviour and `use A2UI.Agent` macro for building agents with minimal boilerplate
- `A2UI.Agent.send_message/2` and `send_messages/2` helpers for agent-to-client messaging
- `A2UI.Connection` opaque handle for transport-agnostic client connections
- SSE + JSON-RPC HTTP transport: `A2UI.Plug`, `A2UI.Plug.SSE`, `A2UI.Plug.JSONRPC`, `A2UI.Plug.ConnectionRegistry`
- `A2UI.Transport.SSE` client-side transport for connecting to SSE endpoints
- A2A protocol transport binding: `A2UI.A2A` server adapter, `A2UI.Transport.A2A` client transport (optional dep on `:a2a ~> 0.2`)
- `A2UI.Protocol.Messages.Error` message type for client-to-server error feedback
- `A2UI.Catalog` module for compile-time component type validation against catalog schemas

### Changed

- Agents track connections as `%{id => Connection.t()}` map instead of `MapSet` of PIDs (**breaking** for custom agent implementations that relied on the internal connection tracking format)
- Demo agent refactored to use `A2UI.Agent` behaviour

### Fixed

- Form handling: added missing `phx-submit` attribute
- Catalog validation: accept custom `component_modules` in validation

## [0.1.0] - 2026-03-06

### Added

- A2UI v0.9 protocol types: Surface, Component, DataModel, Messages
- JSONL parser for protocol message streams
- JSON Pointer (RFC 6901) implementation for data model access
- Data binding with path resolution and function call descriptors
- Component tree management with template expansion
- Surface manager for pure-functional state management
- Phoenix function components for all A2UI component types
- LiveView integration with two-way data binding and action dispatch
- Transport behaviour with local process-messaging implementation
- Video and AudioPlayer components
- Client-side validation via JS hooks (required, regex, length, numeric, email)
- Client-side formatting functions (formatString, formatNumber, formatCurrency, formatDate, pluralize)
- Server-side function evaluation (formatString, formatNumber, formatCurrency, formatDate, pluralize, boolean logic)
- JS interactivity hooks (A2UITabs, A2UIModal, A2UISubmit, A2UIValidation)
- Theming support via CSS variables (primaryColor, iconUrl, agentDisplayName)
- Local action support (openUrl, client-side function calls on Button)
- Demo application with `mix a2ui.demo`

### Fixed

- README: corrected component count (16 → 18), removed completed items from "Not Yet Implemented"
- SPEC.md: added Known Gaps section documenting unimplemented spec features
