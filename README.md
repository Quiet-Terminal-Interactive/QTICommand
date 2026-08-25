# QTICommand

Fluent, chainable command builder + decoupled dispatch library for Godot 4.4+, with an optional themeable console UI, editor dock, testing harness, permissions, cooldowns, fuzzy entity resolution, and a multiplayer bridge.

The command system and the console UI are two separate products glued together. Every feature works with zero UI present, dispatched from chat, RPC, a test harness, the hotkey console, or the editor.

## Install

1. Copy `addons/qti_command/` into your project's `addons/` directory.
2. Project Settings -> Plugins -> enable QTI Command. This registers the `QTICommand` autoload and adds the editor dock automatically (`plugin.gd`). If you don't use the `EditorPlugin` (e.g. exporting the addon into a project without enabling it as a plugin), add `addons/qti_command/autoload/qti_command.gd` as an autoload named `QTICommand` yourself.

## Quick start

```gdscript
QTICommand.register("ping") \
  .description("Replies pong") \
  .execute(func(ctx: QTIContext) -> QTIResult:
    return ctx.ok("pong")
  )

var ctx := QTIContext.new()
ctx.source = &"test"
var result := QTICommand.dispatch("/ping", ctx)
print(result.message)   # "pong"
```

See `examples/example_teleport.gd` for the full fluent-builder surface (args, permissions, cooldowns, aliases), `examples/example_chat_integration.gd` for wiring into a chat system with clean fallthrough, and `examples/example_decorator_style.gd` for the typed-function secondary API.

## Entity resolution

`QTIType.PLAYER_REF` / `QTIType.ENTITY_REF` arguments fuzzy-resolve a typed name against a list of `Node`s but ship with no default fallback. You must register a source before any command using these types is dispatched:

```gdscript
QTICommand.set_entity_source(func() -> Array[Node]:
  return get_tree().get_nodes_in_group("players")
)
```

If a `PLAYER_REF`/`ENTITY_REF` command is dispatched before this is set, the dispatcher fails loudly with `error_type = "runtime"` and a message pointing back here, this is deliberate: a silent empty-match result is indistinguishable from "no player by that name," which is a debugging trap. `QTICommand.register()` also prints a best-effort `push_error()` warning at registration time if a command declares one of these arg types before a source is set (not a hard failure, since `set_entity_source()` may legitimately run later in your `_ready()` order).

Resolution order: exact case-insensitive match -> unique prefix match -> unique fuzzy (Levenshtein-distance) match -> otherwise fails with either a `"Did you mean: a, b?"` disambiguation (`data.candidates`) or `"No entity matching '...'"`.

## Known limitations

- **No try/catch for runtime errors.** GDScript has no exception handling for things like a null dereference inside your `.execute()` callable. `QTIDispatcher` validates that the execute `Callable` is valid before calling it and that it returns a `QTIResult` afterward (converting a bad return into a `runtime`-error `QTIResult`), but a genuine engine-level error inside your command body will still halt script execution the way it would anywhere else in GDScript, this library cannot catch it.
- **`QTICommand.dispatch()` does not implement RPC security.** `.server_only()` routes non-server calls through an RPC and re-runs the full permission check server-side (the trust boundary), but validating who is allowed to act as a given `sender_id` beyond role checks is the game's responsibility.

## Theming

`ui/qti_console_theme.tres` ships as an empty `Theme` resource, a starting point, not a finished skin. `ui/qti_console.gd` builds its child controls in code and assigns this theme to the root `Control`, so populate the `.tres` with your own style-box/font/color overrides in the editor; no `Color()` calls are hardcoded in the console UI scripts.
