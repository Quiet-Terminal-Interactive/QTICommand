## Execution context passed to every command handler.
##
## Carries the invoker identity, parsed arguments, flags, and metadata for a single dispatch call. Also provides convenience factory methods for building [QTIResult] values without importing the class manually.
class_name QTIContext
extends RefCounted

## Emitted when the execute handler calls [method reply]. The console and other UI surfaces listen to this to display streamed output.
signal replied(message: String)

## The object or value that issued this command (e.g. a [Node], a peer ID, or [code]null[/code]). Used by the permission system and history tracking to identify the invoker.
var invoker: Variant = null
## The original unparsed input string passed to [method QTICommand.dispatch].
var raw_input: String = ""
## An application-defined tag identifying the dispatch origin (e.g. [code]&"console"[/code], [code]&"chat"[/code], [code]&"test"[/code]).
var source: StringName = &""
## Arbitrary key-value data attached by the caller. Use this to pass request-scoped state (e.g. [code]{"sender_id": peer_id}[/code]) without subclassing [QTIContext].
var metadata: Dictionary = {}

var _args: Dictionary = {}
var _flags: Dictionary = {}
var _command_name: String = ""

## Returns the parsed value of positional argument [param arg_name], or [code]null[/code] if the argument was optional and not provided.
func arg(arg_name: StringName) -> Variant:
    return _args.get(arg_name)

## Returns [code]true[/code] if the boolean flag [param flag_name] was present in the input.
func has(flag_name: String) -> bool:
    return _flags.get(flag_name, false)

## Creates a successful [QTIResult] for this command.
## [param message] is the human-readable output shown in the console.
## [param data] is an optional structured payload for programmatic consumers.
func ok(message: String = "", data: Dictionary = {}) -> QTIResult:
    return QTIResult.make_ok(_command_name, message, data)

## Creates a failed [QTIResult] for this command.
## [param error_type] classifies the failure (e.g. [code]"validation"[/code],
## [code]"runtime"[/code], [code]"permission"[/code]).
func fail(message: String, error_type: String = "runtime") -> QTIResult:
    return QTIResult.make_fail(_command_name, message, error_type)

## Emits [signal replied] with [param message] for incremental / streamed output. The console connects to this signal to display lines as they are produced.
func reply(message: String) -> void:
    replied.emit(message)
