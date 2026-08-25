## Immutable data record that describes a registered command.
##
## Built by [QTICommandBuilder] and stored in [QTIRegistry].
## Read the fields here for introspection; use [QTICommandBuilder] to author them.
class_name QTICommandDef
extends RefCounted

## Canonical command name used for dispatch and lookup.
var name: String = ""
## Short description shown by [code]/help[/code].
var description: String = ""
## Optional group label used by [code]/list[/code] to organise output.
var category: String = ""
## Alternative names that dispatch to this command.
var aliases: Array[String] = []
## Ordered list of positional arguments accepted by this command.
var positional_args: Array[QTIArgument] = []
## Boolean flags ([code]--name[/code]) accepted by this command.
var flags: Array[QTIArgument] = []
## Role strings required to invoke this command. Any matching role grants access. Empty means no permission check is performed.
var permissions: Array[String] = []
## Minimum seconds between invocations by the same invoker. [code]0.0[/code] disables cooldown.
var cooldown_seconds: float = 0.0
## When [code]true[/code], the command is omitted from [code]/list[/code] and autocomplete.
var is_hidden: bool = false
## When [code]true[/code], a denied invocation returns an unhandled result instead of a permission error, hiding the command's existence from unauthorised invokers.
var hide_when_denied: bool = false
## When [code]true[/code] and a [QTINetBridge] is attached, non-server calls are forwarded to the server instead of executing locally.
var is_server_only: bool = false
## When [code]true[/code], a successful execution triggers [method QTINetBridge.replicate].
var does_replicate: bool = false
## Optional callable [code]() -> bool[/code] that gates availability at dispatch time.
var available_when_callable: Callable
## Optional callable [code](ctx: QTIContext) -> QTIResult[/code] that runs after argument parsing. A failed result aborts execution.
var validate_callable: Callable
## The command body [code](ctx: QTIContext) -> QTIResult[/code].
var execute_callable: Callable

## Returns the [QTIArgument] named [param arg_name] from either positional args or flags, or [code]null[/code] if not found.
func get_arg(arg_name: String) -> QTIArgument:
    for a in positional_args:
        if a.name == arg_name:
            return a
    for f in flags:
        if f.name == arg_name:
            return f
    return null

## Returns a formatted usage string, e.g. [code]teleport <target> [x] [y] [z] [--silent][/code].
func usage_string() -> String:
    var parts: Array[String] = [name]
    for a in positional_args:
        var token := a.name
        if a.rest:
            token = "%s..." % a.name
        if a.optional:
            parts.append("[%s]" % token)
        else:
            parts.append("<%s>" % token)
    for f in flags:
        parts.append("[--%s]" % f.name)
    return " ".join(parts)
