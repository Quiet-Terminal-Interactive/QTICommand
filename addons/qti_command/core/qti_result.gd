## The outcome of a dispatched command.
##
## Returned by [method QTICommand.dispatch] and [method QTICommand.simulate]. Use the static factories ([method make_ok], [method make_fail], [method make_unhandled]) rather than constructing instances directly. Inside a command handler, prefer [method QTIContext.ok] and [method QTIContext.fail] which fill [member command_name] automatically.
class_name QTIResult
extends RefCounted

## Whether the command executed without error.
var success: bool = false
## Human-readable output from the command, suitable for display in the console.
var message: String = ""
## Failure category. Common values: [code]"validation"[/code], [code]"runtime"[/code], [code]"permission"[/code], [code]"cooldown"[/code]. Empty on success.
var error_type: String = ""
## Structured data payload for programmatic consumers. Common keys: [code]"headers"[/code] + [code]"rows"[/code] for table output, [code]"remaining_seconds"[/code] for cooldown results, [code]"candidates"[/code] for disambiguation results, [code]"remote_pending"[/code] for server-forwarded calls.
var data: Dictionary = {}
## The canonical name of the command that produced this result.
var command_name: String = ""
## [code]true[/code] when a registered command handled the input (even if it failed).
## [code]false[/code] for unhandled results (input did not match any command).
var handled: bool = false

## Creates a successful result. Prefer [method QTIContext.ok] inside handlers.
static func make_ok(command_name: String, message: String = "", data: Dictionary = {}) -> QTIResult:
    var r := QTIResult.new()
    r.success = true
    r.handled = true
    r.command_name = command_name
    r.message = message
    r.data = data
    return r

## Creates a failed result. Prefer [method QTIContext.fail] inside handlers.
static func make_fail(command_name: String, message: String, error_type: String = "runtime", data: Dictionary = {}) -> QTIResult:
    var r := QTIResult.new()
    r.success = false
    r.handled = true
    r.command_name = command_name
    r.message = message
    r.error_type = error_type
    r.data = data
    return r

## Creates an unhandled result for input that did not match any registered command. [member handled] is [code]false[/code]; callers can check this to implement fallthrough.
static func make_unhandled(raw_input: String) -> QTIResult:
    var r := QTIResult.new()
    r.success = false
    r.handled = false
    r.command_name = ""
    r.message = ""
    r.error_type = ""
    return r
