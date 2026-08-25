## Abstract base class for argument type parsers.
##
## Extend this class, implement [method parse], and register an instance with [method QTICommand.register_type] to add a custom argument type. Override [method autocomplete] to provide tab-completion suggestions.
class_name QTIArgType
extends RefCounted

## Converts a raw token string into a typed value.
## [param raw] is the unquoted token text from the input.
## [param ctx] is the current dispatch context (available for context-aware parsing).
## Returns a [QTIParseResult] — use [method QTIParseResult.ok] or [method QTIParseResult.fail].
func parse(raw: String, ctx: QTIContext) -> QTIParseResult:
    push_error("QTIArgType.parse() not implemented by %s" % get_script())
    return QTIParseResult.fail("Type not implemented.", "runtime")

## Returns autocomplete suggestions for [param partial], the text typed so far. Return an empty array if this type has no meaningful suggestions.
func autocomplete(partial: String, ctx: QTIContext) -> Array[String]:
    return []
