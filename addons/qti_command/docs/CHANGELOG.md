# Changelog

## 0.1.0

Initial implementation:

- Core dispatch loop: tokenizer, registry, fluent builder, dispatcher, `QTIContext`/`QTIResult`.
- Argument system: built-in types (int/float/string/bool/enum, Vector2/Vector3/Color/NodePath), validation pipeline (range/regex/one_of/length), custom type registration.
- Chat/headless integration pattern (`docs/examples/example_chat_integration.gd`), `dispatch()` requires no `QTIConsole` node anywhere in the scene tree.
- Console UI (`ui/`) as a pure consumer of the dispatcher: output rendering (BBCode + table mode), autocomplete panel, history up/down cycling, hotkey toggle via the `qti_toggle_console` input action.
- Permissions (pluggable resolver, OR-logic roles, `.hide_denied()`) and per-invoker cooldowns.
- Fuzzy player/entity resolution (`QTIType.PLAYER_REF`/`ENTITY_REF`), no default entity source; loud dispatch-time failure if unset.
- Editor dock (`editor/qti_editor_dock.gd`), `@tool`-mode, own dispatcher/registry; refuses `.server_only()` commands with a clear message instead of executing them.
- Multiplayer bridge (`net/qti_net_bridge.gd`): `.server_only()` RPC routing, `.replicate()` hook, server-side-authoritative permission checks.
- Built-in commands (`help`, `list`, `history`, `clear`, `alias`), toggleable via `QTICommand.enable_builtins()`.
- Decorator-style secondary API via `QTICommand.from_function()`
- Testing harness: `QTICommand.simulate()` + `QTITestContext.mock()`.
