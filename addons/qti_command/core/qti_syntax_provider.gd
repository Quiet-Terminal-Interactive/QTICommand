## Defines how ONE input line is split into chained command invocations, tokenized, and bound to argument names.
class_name QTISyntaxProvider
extends RefCounted

## Short identifying name, e.g. [constant QTISyntax.BASH]. Used in error messages.
func get_name() -> String:
    return ""

## Returns a provider instance configured with [param options] (e.g. [code]{"allow_sequence_chaining": true}[/code]). May return [code]self[/code] if this provider has no call-time options. A fresh instance is preferred over mutating [code]self[/code] because one provider name can be simultaneously active in two different configured states (e.g. the global default plus a per-source override).
func with_options(_options: Dictionary) -> QTISyntaxProvider:
    return self

## Runs once per chain link before [method tokenize] / [method bind_arguments], e.g. to perform [code]$var[/code] substitution. The returned string is what both of those methods subsequently see, so raw-remainder offsets used for [code]rest[/code] arguments stay consistent between them.
func prepare_segment(segment: String, _ctx: QTIContext) -> String:
    return segment

## Splits [param raw_input] into an ordered list of [QTIChainLink] (one per command in a chain). Must respect quoting when splitting on chain/pipe operators e.g. a [code];[/code] inside quotes must NOT be treated as a chain separator. Default: no chaining, the whole input is a single link.
func split_chain(raw_input: String) -> Array[QTIChainLink]:
    return [QTIChainLink.new(raw_input, &"start", 0)]

## Tokenizes a single command's argument string (already isolated by [method split_chain] and passed through [method prepare_segment]) into tokens.
func tokenize(_segment: String) -> Array[QTIToken]:
    push_error("QTISyntaxProvider.tokenize() not implemented by %s" % get_script())
    return []

## Maps tokens onto [param def]'s declared arguments and flags. Returns raw string/bool values; type-parsing against [member QTICommandDef.positional_args] still happens afterward in [QTIDispatcher]. [param full_segment] is the same prepared string [param tokens] came from, needed to capture [code]rest[/code] arguments via their original character offsets.
func bind_arguments(_tokens: Array[QTIToken], _def: QTICommandDef, _full_segment: String) -> QTIBindResult:
    push_error("QTISyntaxProvider.bind_arguments() not implemented by %s" % get_script())
    return QTIBindResult.failure("Not implemented.")

## Whether this provider supports piping [member QTIResult.data] into the next command's invocation. If [code]false[/code], the dispatcher rejects [code]|[/code] for this provider with a clear "this syntax does not support piping" error rather than treating it as tokenizable text.
func supports_piping() -> bool:
    return false

## Given the previous command's [QTIResult] and the next command's still-unfilled argument definitions, produce the implicit bound values a pipe should inject. Only called if [method supports_piping] is [code]true[/code]. See [method _default_resolve_pipe_input] for the shared [code]pipe_value[/code]/[code]pipe_list[/code] convention.
func resolve_pipe_input(_previous_result: QTIResult, _next_arg_defs: Array[QTIArgument]) -> Dictionary:
    return {}

## Display-only: the operator strings this provider recognizes, so console UI/autocomplete can hint them (e.g. syntax-highlighting [code]&&[/code] in the input field). Purely cosmetic; no dispatcher behavior depends on this.
func get_chain_operators() -> Dictionary:
    return {}

## Shared implementation of the pipe data-shape convention, available to subclasses that support
## piping so it's implemented exactly once:
## [br]- [code]previous_result.data["pipe_list"][/code] (Array) — if the next command's first unfilled arg is a [code]rest[/code] arg, the whole list is joined with [code]"\n"[/code] and bound there (there is no array-typed [QTIArgument] to bind a real list into); otherwise only the first element is used and a warning is logged.
## [br]- Else [code]previous_result.data["pipe_value"][/code] — bound directly to the first unfilled arg.
## [br]- Else falls back to piping [member QTIResult.message] as plain text, so piping degrades gracefully for commands that were never written with piping in mind.
func _default_resolve_pipe_input(previous_result: QTIResult, next_arg_defs: Array[QTIArgument]) -> Dictionary:
    if previous_result == null or next_arg_defs.is_empty():
        return {}
    var target: QTIArgument = next_arg_defs[0]
    var data := previous_result.data
    if data.has("pipe_list") and data["pipe_list"] is Array:
        var list: Array = data["pipe_list"]
        if list.is_empty():
            return {}
        if target.rest:
            var strs: Array[String] = []
            for v in list:
                strs.append(str(v))
            return {target.name: "\n".join(strs)}
        if list.size() > 1:
            push_warning("QTICommand: piping %d values into single-value argument '%s'; using only the first." % [list.size(), target.name])
        return {target.name: str(list[0])}
    if data.has("pipe_value"):
        return {target.name: str(data["pipe_value"])}
    return {target.name: previous_result.message}
