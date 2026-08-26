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

## 0.2.0

Pluggable command syntax, chaining, and piping:

- New `QTISyntaxProvider` interface (`core/qti_syntax_provider.gd`) governing how one input line is split into a chain of command invocations, tokenized, and bound to argument names. Install with `QTICommand.set_syntax()` / `QTICommand.register_syntax()`, globally or per-`ctx.source`.
- Three built-in syntaxes (`QTISyntax.DEFAULT`, `QTISyntax.BASH`, `QTISyntax.POWERSHELL`): `DEFAULT` reproduces the pre-existing grammar exactly, with an opt-in `;`-only sequence-chaining flag; `BASH` adds `&&`/`||`/`;` chaining, `|` piping, and `$var`/`${var}` substitution against `ctx.metadata`; `POWERSHELL` adds named-parameter binding (`-Target john`), `;` chaining, and `|` piping.
- Piping convention: a command opts in with `ctx.ok(message, {"pipe_value": ...})` or `{"pipe_list": [...]}`; piping degrades gracefully to plain-text piping (the previous command's `message`) for commands that don't opt in.
- `QTIHistory`/`command_executed`/`command_failed` now treat an entire chain as one dispatch, not one per link and history now records the actual raw input, not just the last resolved command's bare name.
- `QTITokenizer` is now a thin wrapper over the new `QTITokenizerUtil`, which every syntax provider shares for quote-aware tokenizing, chain/pipe-operator splitting, and `$var` substitution.
- `QTITestContext.mock()` now pins `QTISyntax.DEFAULT` by default (override via `{"syntax": ...}`) so tests are isolated from whatever syntax a real game has configured globally.
- Fixed a pre-existing bug where a `rest`-type argument capturing more than one whitespace-separated word (e.g. the `alias` builtin's `<command...>`, or any multi-word `say <message...>`-style command) incorrectly failed with "Too many arguments."
- See `docs/SYNTAX.md` for the full reference and a security note on enabling chaining/piping for untrusted/chat-sourced input.