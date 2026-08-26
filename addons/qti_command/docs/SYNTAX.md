# Syntax providers

A `QTISyntaxProvider` decides how one line of input is split into a chain of command invocations, tokenized, and bound to argument names. This is shell-style sequencing/piping between whole, already-registered commands (`&&`, `||`, `;`, `|`).

## Choosing a syntax

```gdscript
QTICommand.set_syntax(QTISyntax.BASH)
QTICommand.set_syntax(QTISyntax.POWERSHELL, {"source": &"console"})   # per-source override
QTICommand.register_syntax("fish", QTIFishSyntaxProvider.new())      # your own QTISyntaxProvider
QTICommand.set_syntax("fish")
```

`set_syntax(syntax, source_filter)`: if `source_filter` contains a `"source"` key, this sets a per-source override (checked against `ctx.source`) instead of the global default; any other keys are passed to the provider as options. Per-source overrides are checked before the global default, and both are checked after `ctx.syntax_override` (see "Testing" below).

## Built-in syntaxes

### `QTISyntax.DEFAULT`

Default grammar: whitespace/quote tokenization, `"..."` with `\"` escape, `--flag` / `--flag=value`, no chaining, no piping. Opt in to `;`-only sequencing  (always-run, no short-circuit semantics, `&&` and `||` stay unavailable in this syntax):

```gdscript
QTICommand.set_syntax(QTISyntax.DEFAULT, {"allow_sequence_chaining": true})
```

`supports_piping()` is always `false` for `DEFAULT`, regardless of this flag.

### `QTISyntax.BASH`

- Chaining: `&&` (run next only if previous succeeded), `||` (run next only if previous failed), `;` (always run next).
- Piping: `|` — see "Piping" below.
- Quoting: double quotes with `\"` escape (same as `DEFAULT`), plus literal single-quote spans (`'...'`, no escape processing inside).
- `$var` / `${var}` substitution against `ctx.metadata`: applied inside double quotes and unquoted text, suppressed inside single quotes. `\$` outside single quotes becomes a literal `$`. A referenced variable that isn't in `ctx.metadata` substitutes an empty string and logs a `push_warning`.
- Empty segments (e.g. `a;;b`) are skipped silently, not an error.

### `QTISyntax.POWERSHELL`

- Chaining: `;` only (no `&&`/`||`).
- Piping: `|`, same convention as BASH.
- Named parameters: `-Target john -Amount 100` bind directly to a declared argument/flag by name (case-insensitive). A `.flag()`-declared boolean binds as a switch: `-Silent` alone (no following value) sets it `true`. Remaining, unnamed tokens fill remaining unbound positional arguments in declared order, so named and positional args can mix: `teleport -Z 10 5 5` binds `Z=10` then fills `x=5, y=5` positionally.
- A token that looks like a negative number (`-5`, `-1.5`) is never treated as a parameter name, so it always falls through to positional binding.
- A `-Foo` that isn't a negative-number-looking token and doesn't match any declared argument/flag is a binding error: `"Unknown parameter: -Foo"`.

## Piping

The `pipe_value` / `pipe_list` convention lets a command's output feed the next command's first still-unfilled argument, without requiring every command author to think about piping:

- If the previous command's `QTIResult.data` has a `"pipe_list"` key (an `Array`) and the next command's first unfilled positional argument is a `rest` argument, the whole list is joined with `"\n"` and bound there (there's no array-typed argument to bind a real list into). Otherwise, only the first element is used and a warning is logged.
- Else, if `data` has a `"pipe_value"` key, it's bound directly to the first unfilled argument.
- Else, the previous command's `message` (its display text) is piped as plain text, so piping degrades gracefully for commands that were never written with piping in mind.
- An explicit value already present in the piped-to segment's own text always wins over a piped value, piping only fills in what's otherwise missing.
- Opting in as a command author needs no new API: `ctx.ok(message, {"pipe_list": [...]})`.

Piping into a `.server_only()` command from a non-server peer is rejected with a clear error rather than silently dropped, there's currently no way to carry an already-computed local `QTIResult` across the existing RPC boundary (`net/qti_net_bridge.gd`), which only forwards raw command strings.

## Chaining semantics

`&&`/`||`/`;`/`|` between links behave like a shell: `&&` short-circuits if the previous link failed, `||` short-circuits if the previous link succeeded, `;` always runs the next link regardless. The `QTIResult` returned from `dispatch()` reflects the last executed link, consistent with a shell's `$?` reflecting the last command run. A command chained past position 0 that doesn't resolve to any registered command is treated as a real failure (`error_type = "not_found"`), not as "unhandled input"; that distinction only matters for a single, non-chained unknown command, where callers commonly treat "unhandled" as a signal to fall through to other handling (e.g. plain chat text). `QTIHistory` and `command_executed`/`command_failed` see the whole chain as one dispatch, not one per link.

## Security note

If you route chat text (or any other untrusted input) through `QTICommand.dispatch()`, think carefully before enabling chaining or piping on that source. Chaining/piping does not bypass the permission resolver or argument validation, each chained command is still fully checked and validated independently, but it does let an invoker compose multiple  already-permitted actions in one message, and it makes any `rest`-type (free-text) argument chain-splittable unless the invoker quotes it: `say "hello; ban everyone"` is one command under `BASH` syntax, but unquoted `say hello; ban everyone` is two, exactly like a real shell. `QTISyntax.DEFAULT` with `allow_sequence_chaining` left at its default `false` is the safest choice for untrusted input.

## Testing

`QTITestContext.mock()` always pins `ctx.syntax_override` to `QTISyntax.DEFAULT` unless you pass a `"syntax"` override, so `QTICommand.simulate()` calls in tests never depend on whatever syntax a real game has configured globally:

```gdscript
var result := QTICommand.simulate(
    "list_players && teleport john 0 0 0",
    QTITestContext.mock({"syntax": QTISyntax.BASH})
)
assert(result.success)
```
