## The outcome of parsing a single raw token into a typed value.
##
## Returned by [method QTIArgType.parse] and [method QTITypeRegistry.parse]. Use the static factories ([method ok], [method fail]) to construct instances.
class_name QTIParseResult
extends RefCounted

## Whether parsing succeeded.
var success: bool = false
## The parsed value on success. [code]null[/code] on failure.
var value: Variant = null
## Human-readable parse error. Empty on success.
var error_message: String = ""
## Failure category forwarded to the [QTIResult]. Default is [code]"validation"[/code].
var error_type: String = "validation"
## Optional structured payload attached to the failure result.
var data: Dictionary = {}

## Creates a successful parse result wrapping [param value].
static func ok(value: Variant) -> QTIParseResult:
    var r := QTIParseResult.new()
    r.success = true
    r.value = value
    return r

## Creates a failed parse result with a human-readable [param message]. [param error_type] is forwarded as [member QTIResult.error_type] (default [code]"validation"[/code]).
static func fail(message: String, error_type: String = "validation", data: Dictionary = {}) -> QTIParseResult:
    var r := QTIParseResult.new()
    r.success = false
    r.error_message = message
    r.error_type = error_type
    r.data = data
    return r
