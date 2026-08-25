## Fluent builder that constructs and registers a [QTICommandDef].
##
## Obtain an instance from [method QTICommand.register] or [method QTICommand.from_function] and chain calls to configure the command. Calling [method execute] finalises the definition and registers it; no builder method may be called after that point.
class_name QTICommandBuilder
extends RefCounted

var _def: QTICommandDef
var _registry: QTIRegistry
var _finalized: bool = false

func _init(p_name: String, p_registry: QTIRegistry) -> void:
    _def = QTICommandDef.new()
    _def.name = p_name
    _registry = p_registry

func _check_not_finalized() -> void:
    assert(not _finalized, "QTICommandBuilder: cannot call builder methods after .execute() has finalized command '%s'." % _def.name)

## Sets the human-readable description shown by [code]/help[/code].
func description(text: String) -> QTICommandBuilder:
    _check_not_finalized()
    _def.description = text
    return self

## Groups this command under [param name] in [code]/list[/code] output.
func category(name: String) -> QTICommandBuilder:
    _check_not_finalized()
    _def.category = name
    return self

## Registers an additional name that dispatches this command. May be called multiple times to add more than one alias.
func alias(name: String) -> QTICommandBuilder:
    _check_not_finalized()
    _def.aliases.append(name)
    return self

## Appends a positional argument to the command signature.
## [param name] is the key used in [method QTIContext.get].
## [param type] is one of the [QTIType] string constants or a custom registered type.
## [param opts] may contain:
## [br]- [code]optional[/code] ([bool]) — argument may be omitted.
## [br]- [code]default[/code] ([Variant]) — value used when the argument is absent (implies optional).
## [br]- [code]rest[/code] ([bool]) — consumes all remaining input as a raw string.
## [br]- [code]min[/code] / [code]max[/code] — numeric range constraint.
## [br]- [code]regex[/code] ([String]) — pattern the string value must match.
## [br]- [code]one_of[/code] ([Array]) — explicit allowed value list.
## [br]- [code]min_length[/code] / [code]max_length[/code] ([int]) — string length constraints.
func arg(name: String, type: String, opts: Dictionary = {}) -> QTICommandBuilder:
    _check_not_finalized()
    var new_arg := QTIArgument.new(name, type, opts)
    for i in range(_def.positional_args.size()):
        if _def.positional_args[i].name == name:
            _def.positional_args[i] = new_arg
            return self
    _def.positional_args.append(new_arg)
    return self

## Appends a boolean flag ([code]--name[/code]) to the command signature. Flags are always optional; [method QTIContext.has] returns [code]true[/code] when the flag was present in the input.
func flag(name: String, opts: Dictionary = {}) -> QTICommandBuilder:
    _check_not_finalized()
    var a := QTIArgument.new(name, QTIType.BOOL, opts)
    a.is_flag = true
    _def.flags.append(a)
    return self

## Requires the invoker to hold [param role] (as checked by the active [QTIPermissionResolver]) before the command is executed. May be called multiple times; any matching role grants access.
func permission(role: String) -> QTICommandBuilder:
    _check_not_finalized()
    _def.permissions.append(role)
    return self

## Prevents the same invoker from running this command more than once per [param seconds] interval. Returns a [code]"cooldown"[/code] error result with [code]data.remaining_seconds[/code] when the limit is active.
func cooldown(seconds: float) -> QTICommandBuilder:
    _check_not_finalized()
    _def.cooldown_seconds = seconds
    return self

## Excludes this command from [code]/list[/code] output and autocomplete. Denied invocations also return an unhandled result instead of a permission error.
func hidden() -> QTICommandBuilder:
    _check_not_finalized()
    _def.is_hidden = true
    return self

## When the invoker lacks permission, returns an unhandled result rather than a [code]"permission"[/code] error, effectively hiding the command's existence.
func hide_denied() -> QTICommandBuilder:
    _check_not_finalized()
    _def.hide_when_denied = true
    return self

## Marks this command as server-authoritative. When dispatched on a non-server peer in a networked session, the raw input is forwarded to the server via [QTINetBridge] and the call returns a [code]remote_pending[/code] result.
func server_only() -> QTICommandBuilder:
    _check_not_finalized()
    _def.is_server_only = true
    return self

## Calls [method QTINetBridge.replicate] after a successful execution so the result can be broadcast to other peers by the replication handler.
func replicate() -> QTICommandBuilder:
    _check_not_finalized()
    _def.does_replicate = true
    return self

## Attaches a validation callable that runs after argument parsing but before [method execute]. The callable receives the populated [QTIContext] and must return a [QTIResult]; returning a failed result aborts execution.
func validate(callable: Callable) -> QTICommandBuilder:
    _check_not_finalized()
    _def.validate_callable = callable
    return self

## Attaches a callable that gates command availability at dispatch time. The callable takes no arguments and must return a [bool]; returning [code]false[/code] makes the command behave as if it were unregistered.
func available_when(callable: Callable) -> QTICommandBuilder:
    _check_not_finalized()
    _def.available_when_callable = callable
    return self

## Finalises and registers the command with the given execute handler. [param callable] receives a fully-populated [QTIContext] and must return a [QTIResult]. No further builder methods may be called after this.
func execute(callable: Callable) -> QTICommandBuilder:
    _check_not_finalized()
    _def.execute_callable = callable
    _finalized = true
    _registry.register_command(_def)
    return self

## Inspects [param callable]'s method signature via reflection and returns a [QTICommandBuilder] whose positional arguments mirror the function parameters. The first parameter is skipped when it is typed [QTIContext] or named [code]ctx[/code] / [code]context[/code]. GDScript default values are mapped to optional arguments automatically.
static func from_function(callable: Callable, name: String, registry: QTIRegistry) -> QTICommandBuilder:
    var builder := QTICommandBuilder.new(name, registry)
    if not callable.is_valid():
        push_error("QTICommand.from_function('%s'): callable is not valid; registering with no inferred arguments." % name)
        return builder

    var method_name := callable.get_method()
    var target: Object = callable.get_object()
    if target == null:
        return builder

    for m in target.get_method_list():
        if m.name != method_name:
            continue
        var m_args: Array = m.args
        var default_args: Array = m.default_args
        var required_count: int = m_args.size() - default_args.size()

        var start_index := 0
        if m_args.size() > 0:
            var first: Dictionary = m_args[0]
            var first_class := String(first.get("class_name", ""))
            if first_class == "QTIContext" or first.get("name", "") in ["ctx", "context"]:
                start_index = 1

        for i in range(start_index, m_args.size()):
            var arg_info: Dictionary = m_args[i]
            var arg_name: String = arg_info.get("name", "arg%d" % i)
            var type_name := QTITypeRegistry.godot_variant_type_to_qti_type(arg_info.get("type", TYPE_NIL))
            var opts := {}
            var default_index := i - required_count
            if default_index >= 0 and default_index < default_args.size():
                opts["optional"] = true
                opts["default"] = default_args[default_index]
            builder.arg(arg_name, type_name, opts)
        break

    return builder
