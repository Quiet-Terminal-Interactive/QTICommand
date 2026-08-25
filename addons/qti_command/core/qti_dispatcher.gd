## Parses raw input, resolves commands, enforces permissions and cooldowns, and invokes execute handlers.
##
## Owned by [QTICommand]. Use [method QTICommand.dispatch] instead of calling this class directly.
class_name QTIDispatcher
extends RefCounted

## Emitted after a command executes successfully.
signal command_executed(result: QTIResult)
## Emitted after a command fails at any stage (permission, cooldown, validation, execute).
signal command_failed(result: QTIResult)

## The command registry used for lookup.
var registry: QTIRegistry
## The type registry used for argument parsing and autocomplete.
var type_registry: QTITypeRegistry
## The permission resolver consulted before each execution.
var permission_resolver: QTIPermissionResolver
## The optional network bridge for server-only routing and replication.
var net_bridge: QTINetBridge = null
## String that raw input must begin with to be treated as a command (default [code]"/"[/code]).
var prefix: String = "/"
## When [code]true[/code], command name lookup is case-sensitive.
var case_sensitive: bool = false

## Tracks the last execution timestamp per [code]invoker_key:command_name[/code] for cooldown enforcement.
var cooldown_tracker: Dictionary = {}

func _init(p_registry: QTIRegistry, p_type_registry: QTITypeRegistry, p_permission_resolver: QTIPermissionResolver) -> void:
    registry = p_registry
    type_registry = p_type_registry
    permission_resolver = p_permission_resolver

## Returns a stable string key that uniquely identifies the invoker in [param ctx]. Used for per-invoker cooldown tracking and history recording.
func invoker_key(ctx: QTIContext) -> String:
    if ctx.invoker == null:
        return "anon"
    if ctx.invoker is Object:
        return str(ctx.invoker.get_instance_id())
    return str(ctx.invoker)

## Returns [code]true[/code] if the invoker in [param ctx] satisfies at least one of the required roles on [param def], or if [param def] has no requirements.
func check_permission(def: QTICommandDef, ctx: QTIContext) -> bool:
    if def.permissions.is_empty():
        return true
    for role in def.permissions:
        if permission_resolver.has_permission(ctx.invoker, role):
            return true
    return false

## Parses [param raw_input], resolves the command, checks permissions and cooldowns, parses arguments, runs the validate callable (if any), and calls the execute handler. When [param emit_signals] is [code]false[/code], [signal command_executed] and [signal command_failed] are suppressed (used by [method QTICommand.simulate]).
func dispatch(raw_input: String, ctx: QTIContext, emit_signals: bool = true) -> QTIResult:
    ctx.raw_input = raw_input
    var trimmed := raw_input.strip_edges()

    if prefix != "" and not trimmed.begins_with(prefix):
        return QTIResult.make_unhandled(raw_input)

    var body := trimmed.substr(prefix.length()) if prefix != "" else trimmed
    if body.strip_edges() == "":
        return QTIResult.make_unhandled(raw_input)

    var tokens := QTITokenizer.tokenize(body)
    if tokens.is_empty():
        return QTIResult.make_unhandled(raw_input)

    var cmd_token := tokens[0]
    var cmd_name := cmd_token.text if case_sensitive else cmd_token.text.to_lower()

    var runtime_target := registry.resolve_runtime_alias(cmd_name)
    if runtime_target != "":
        var rest := QTITokenizer.raw_remainder(body, cmd_token.end)
        var new_body := runtime_target if rest == "" else "%s %s" % [runtime_target, rest]
        return dispatch(prefix + new_body, ctx, emit_signals)

    var def := registry.get_command(cmd_name)
    if def == null:
        return QTIResult.make_unhandled(raw_input)

    ctx._command_name = def.name

    if def.available_when_callable.is_valid() and not def.available_when_callable.call():
        return QTIResult.make_unhandled(raw_input)

    if not check_permission(def, ctx):
        if def.is_hidden or def.hide_when_denied:
            return QTIResult.make_unhandled(raw_input)
        var denied := QTIResult.make_fail(def.name, "You do not have permission to run this command.", "permission")
        if emit_signals:
            command_failed.emit(denied)
        return denied

    if def.cooldown_seconds > 0.0:
        var key := "%s:%s" % [invoker_key(ctx), def.name]
        var now := Time.get_ticks_msec() / 1000.0
        if cooldown_tracker.has(key):
            var elapsed: float = now - cooldown_tracker[key]
            if elapsed < def.cooldown_seconds:
                var remaining: float = def.cooldown_seconds - elapsed
                var on_cooldown := QTIResult.make_fail(def.name, "Command on cooldown (%.1fs remaining)." % remaining, "cooldown", {"remaining_seconds": remaining})
                if emit_signals:
                    command_failed.emit(on_cooldown)
                return on_cooldown

    if def.is_server_only and net_bridge != null and net_bridge.is_networked() and not net_bridge.is_server():
        net_bridge.request_remote_dispatch(raw_input)
        var pending := QTIResult.make_ok(def.name, "Command sent to server.")
        pending.data["remote_pending"] = true
        return pending

    var rest_tokens := tokens.slice(1)
    var extraction := QTITokenizer.extract_flags(rest_tokens)
    var positional_tokens: Array = extraction["positional"]
    var flag_values: Dictionary = extraction["flags"]

    var parsed := _parse_arguments(def, positional_tokens, body, ctx)
    if not parsed["success"]:
        var fail_result: QTIResult = parsed["result"]
        if emit_signals:
            command_failed.emit(fail_result)
        return fail_result
    ctx._args = parsed["args"]

    ctx._flags = {}
    for f in def.flags:
        ctx._flags[f.name] = flag_values.get(f.name, false)

    if def.validate_callable.is_valid():
        var validation = def.validate_callable.call(ctx)
        if validation is QTIResult and not validation.success:
            if emit_signals:
                command_failed.emit(validation)
            return validation

    if not def.execute_callable.is_valid():
        var no_handler := QTIResult.make_fail(def.name, "Command '%s' has no execute handler." % def.name, "runtime")
        if emit_signals:
            command_failed.emit(no_handler)
        return no_handler

    var raw_result = def.execute_callable.call(ctx)
    var result: QTIResult
    if raw_result is QTIResult:
        result = raw_result
    else:
        push_error("QTICommand: command '%s' execute callable did not return a QTIResult (got %s)." % [def.name, typeof(raw_result)])
        result = QTIResult.make_fail(def.name, "Internal error: command produced an invalid result.", "runtime")

    result.command_name = def.name
    result.handled = true

    if def.cooldown_seconds > 0.0:
        cooldown_tracker["%s:%s" % [invoker_key(ctx), def.name]] = Time.get_ticks_msec() / 1000.0

    if emit_signals:
        if result.success:
            command_executed.emit(result)
        else:
            command_failed.emit(result)

    if def.does_replicate and result.success and net_bridge != null:
        net_bridge.replicate(def.name, result)

    return result

## Returns command-name and argument-value suggestions for [param partial_input]. Suggestions are full strings (prefix included) ready to replace the input field.
func autocomplete(partial_input: String, ctx: QTIContext) -> Array[String]:
    var suggestions: Array[String] = []
    var trimmed := partial_input
    if prefix != "" and trimmed.begins_with(prefix):
        trimmed = trimmed.substr(prefix.length())
    var tokens := QTITokenizer.tokenize(trimmed)
    var ends_with_space := partial_input.ends_with(" ")

    if tokens.is_empty() or (tokens.size() == 1 and not ends_with_space):
        var partial_name := tokens[0].text if not tokens.is_empty() else ""
        for def in registry.list_all():
            if def.is_hidden:
                continue
            if not check_permission(def, ctx):
                continue
            if def.available_when_callable.is_valid() and not def.available_when_callable.call():
                continue
            for c in [def.name] + def.aliases:
                if c.begins_with(partial_name):
                    suggestions.append(prefix + c)
        return suggestions

    var cmd_name := tokens[0].text if case_sensitive else tokens[0].text.to_lower()
    var def := registry.get_command(cmd_name)
    if def == null:
        return suggestions

    var arg_index := tokens.size() if ends_with_space else tokens.size() - 1
    var partial_value := "" if ends_with_space else tokens[tokens.size() - 1].text
    var positional_index := arg_index - 1
    if positional_index >= 0 and positional_index < def.positional_args.size():
        var arg_def: QTIArgument = def.positional_args[positional_index]
        suggestions = type_registry.autocomplete(arg_def.type, partial_value, ctx)
        if not arg_def.one_of.is_empty():
            for v in arg_def.one_of:
                var s := str(v)
                if s.begins_with(partial_value) and not suggestions.has(s):
                    suggestions.append(s)
    return suggestions

func _parse_arguments(def: QTICommandDef, tokens: Array, full_body: String, ctx: QTIContext) -> Dictionary:
    var args := {}
    var n := def.positional_args.size()
    for i in range(n):
        var arg_def: QTIArgument = def.positional_args[i]
        var token: QTITokenizer.Token = tokens[i] if i < tokens.size() else null

        if arg_def.rest:
            var raw := QTITokenizer.raw_remainder(full_body, token.start) if token != null else ""
            if raw == "":
                if arg_def.has_default:
                    args[arg_def.name] = arg_def.default
                elif arg_def.optional:
                    args[arg_def.name] = null
                else:
                    return {"success": false, "result": _missing_arg_result(def, arg_def)}
            else:
                args[arg_def.name] = raw
            continue

        if token == null:
            if arg_def.has_default:
                args[arg_def.name] = arg_def.default
                continue
            if arg_def.optional:
                args[arg_def.name] = null
                continue
            return {"success": false, "result": _missing_arg_result(def, arg_def)}

        var parse_result: QTIParseResult = type_registry.parse(arg_def.type, token.text, ctx)
        if not parse_result.success:
            var msg := parse_result.error_message
            if parse_result.error_type != "runtime":
                msg = "Invalid value for '%s': %s" % [arg_def.name, parse_result.error_message]
            return {"success": false, "result": QTIResult.make_fail(def.name, msg, parse_result.error_type, parse_result.data)}

        var validation_error := _validate_value(arg_def, parse_result.value)
        if validation_error != "":
            return {"success": false, "result": QTIResult.make_fail(def.name, validation_error, "validation")}

        args[arg_def.name] = parse_result.value

    if tokens.size() > n:
        return {"success": false, "result": QTIResult.make_fail(def.name, "Too many arguments for '%s'. Usage: %s" % [def.name, def.usage_string()], "validation")}

    return {"success": true, "args": args}

func _missing_arg_result(def: QTICommandDef, arg_def: QTIArgument) -> QTIResult:
    return QTIResult.make_fail(def.name, "Missing required argument '%s'. Usage: %s" % [arg_def.name, def.usage_string()], "validation")

func _validate_value(arg_def: QTIArgument, value: Variant) -> String:
    if arg_def.min_value != null and value < arg_def.min_value:
        return "'%s' must be >= %s (got %s)." % [arg_def.name, arg_def.min_value, value]
    if arg_def.max_value != null and value > arg_def.max_value:
        return "'%s' must be <= %s (got %s)." % [arg_def.name, arg_def.max_value, value]
    if arg_def.regex != "" and value is String:
        var re := RegEx.new()
        if re.compile(arg_def.regex) == OK and re.search(value) == null:
            return "'%s' does not match the required pattern." % arg_def.name
    if not arg_def.one_of.is_empty() and not arg_def.one_of.has(value):
        return "'%s' must be one of: %s (got %s)." % [arg_def.name, arg_def.one_of, value]
    if arg_def.min_length >= 0 and value is String and value.length() < arg_def.min_length:
        return "'%s' must be at least %d characters." % [arg_def.name, arg_def.min_length]
    if arg_def.max_length >= 0 and value is String and value.length() > arg_def.max_length:
        return "'%s' must be at most %d characters." % [arg_def.name, arg_def.max_length]
    return ""
