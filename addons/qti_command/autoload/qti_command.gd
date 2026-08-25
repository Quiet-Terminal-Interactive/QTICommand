## Global autoload singleton that owns the entire QTI command system.
##
## Register commands with [method register] or [method from_function], dispatch raw input with [method dispatch], and configure the system (prefix, permissions, entity source, history, networking) through the methods below.
## [br][br]
## Added automatically as the [code]QTICommand[/code] autoload when the plugin is enabled. If you skip the EditorPlugin, add [code]addons/qti_command/autoload/qti_command.gd[/code] as an autoload named [code]QTICommand[/code] yourself.
extends Node

## Emitted after a new command is successfully registered.
signal command_registered(def: QTICommandDef)
## Emitted after a command executes and returns a successful [QTIResult].
signal command_executed(result: QTIResult)
## Emitted after a command executes and returns a failed [QTIResult], or when dispatch rejects the invocation (wrong permission, cooldown, etc.).
signal command_failed(result: QTIResult)

var _registry: QTIRegistry
var _type_registry: QTITypeRegistry
var _permission_resolver: QTIPermissionResolver
var _dispatcher: QTIDispatcher
var _history: QTIHistory
var _net_bridge: QTINetBridge = null
var _builtins_enabled: bool = true
var _builtins_registered: bool = false
var _last_invoker_key: String = ""

func _ready() -> void:
    _type_registry = QTITypeRegistry.new()
    _registry = QTIRegistry.new(_type_registry)
    _permission_resolver = QTIPermissionResolver.new()
    _dispatcher = QTIDispatcher.new(_registry, _type_registry, _permission_resolver)
    _history = QTIHistory.new()

    _dispatcher.command_executed.connect(_on_dispatcher_executed)
    _dispatcher.command_failed.connect(_on_dispatcher_failed)
    _registry.command_registered.connect(func(def: QTICommandDef) -> void: command_registered.emit(def))

    if _builtins_enabled:
        enable_builtins(true)

func _on_dispatcher_executed(result: QTIResult) -> void:
    _history.record(_last_invoker_key, result.command_name, true)
    command_executed.emit(result)

func _on_dispatcher_failed(result: QTIResult) -> void:
    _history.record(_last_invoker_key, result.command_name, false)
    command_failed.emit(result)

## Returns a fluent [QTICommandBuilder] for [param name]. Chain builder calls and end with [method QTICommandBuilder.execute] to register.
## [codeblock]
## QTICommand.register("ping") \
##     .description("Replies pong") \
##     .execute(func(ctx): return ctx.ok("pong"))
## [/codeblock]
func register(name: String) -> QTICommandBuilder:
    return QTICommandBuilder.new(name, _registry)

## Removes the command with [param name] (and all its aliases) from the registry. No-op if the command does not exist.
func unregister(name: String) -> void:
    _registry.unregister_command(name)

## Registers a custom argument type under [param type_name]. [param parser] must be a [QTIArgType] whose [method QTIArgType.parse] converts a raw token string into a typed value.
func register_type(type_name: String, parser: QTIArgType) -> void:
    _type_registry.register_type(type_name, parser)

## Inspects [param callable]'s parameter list via reflection and returns a [QTICommandBuilder] pre-populated with matching argument definitions. The first parameter is skipped if it is typed [QTIContext] or named [code]ctx[/code] / [code]context[/code].
func from_function(callable: Callable, name: String) -> QTICommandBuilder:
    return QTICommandBuilder.from_function(callable, name, _registry)

## Parses and dispatches [param raw_input] using [param context]. Returns a [QTIResult] describing the outcome. Emits [signal command_executed] or [signal command_failed] and records the call in history.
func dispatch(raw_input: String, context: QTIContext) -> QTIResult:
    _last_invoker_key = _dispatcher.invoker_key(context)
    return _dispatcher.dispatch(raw_input, context, true)

## Returns [code]true[/code] if [param context] passes all permission checks for the command named [param name]. Returns [code]false[/code] if the command does not exist or the invoker lacks a required role.
func can_execute(name: String, context: QTIContext) -> bool:
    var def := _registry.get_command(name)
    if def == null:
        return false
    return _dispatcher.check_permission(def, context)

## Returns autocomplete suggestions for the partial input string. Suggestions are full command strings (including the prefix) or argument values.
func autocomplete(partial_input: String, context: QTIContext) -> Array[String]:
    return _dispatcher.autocomplete(partial_input, context)

## Returns the [QTICommandDef] registered under [param name], or [code]null[/code] if no such command (or alias) exists.
func get_command(name: String) -> QTICommandDef:
    return _registry.get_command(name)

## Returns all registered commands visible and accessible to [param context]. Hidden commands and commands the invoker cannot execute are excluded. Pass [code]null[/code] to return every registered command unfiltered.
func list_commands(context: QTIContext = null) -> Array[QTICommandDef]:
    var all := _registry.list_all()
    if context == null:
        return all
    var out: Array[QTICommandDef] = []
    for def in all:
        if def.is_hidden:
            continue
        if not _dispatcher.check_permission(def, context):
            continue
        out.append(def)
    return out

## Returns the [QTIHistory] instance that records all dispatched commands.
func get_history() -> QTIHistory:
    return _history

## Creates a runtime alias: typing [param name] will expand to [param command_string] before dispatch. Unlike compile-time aliases, these can be set and changed at runtime (e.g. from player settings or a chat shortcut command).
func set_runtime_alias(name: String, command_string: String) -> void:
    _registry.set_runtime_alias(name, command_string)

## Replaces the permission resolver used for all future permission checks. Extend [QTIPermissionResolver] and override [method QTIPermissionResolver.has_permission] to integrate with your game's role system.
func set_permission_resolver(resolver: QTIPermissionResolver) -> void:
    _permission_resolver = resolver
    _dispatcher.permission_resolver = resolver

## Sets the command prefix (default [code]"/"[/code]). Input that does not start with this prefix is returned as an unhandled result. Set to [code]""[/code] to accept all input.
func set_prefix(prefix: String) -> void:
    _dispatcher.prefix = prefix

## Returns the currently active command prefix.
func get_prefix() -> String:
    return _dispatcher.prefix

## When [param enabled] is [code]true[/code], command names are matched case-sensitively. Default is [code]false[/code] (case-insensitive).
func set_case_sensitive(enabled: bool) -> void:
    _dispatcher.case_sensitive = enabled

## Provides the list of nodes used to resolve [code]QTIType.PLAYER_REF[/code] and [code]QTIType.ENTITY_REF[/code] arguments. [param callable] must return an [code]Array[Node][/code].
## [codeblock]
## QTICommand.set_entity_source(func() -> Array[Node]:
##     return get_tree().get_nodes_in_group("players")
## )
## [/codeblock]
func set_entity_source(callable: Callable) -> void:
    _type_registry.set_entity_source(callable)

## Enables or disables disk persistence for dispatch history. [param opts] may contain:
## [br]- [code]max_entries[/code] ([int]) — maximum entries kept (default 200).
## [br]- [code]exclude_patterns[/code] ([Array]) — substring or regex patterns; matching inputs are not saved.
func set_history_persistence(enabled: bool, opts: Dictionary = {}) -> void:
    _history.set_persistence(enabled, opts)

## Attaches a [QTINetBridge] node to enable multiplayer routing. Must be called before any [code]server_only()[/code] command is dispatched.
func attach_net_bridge(bridge: QTINetBridge) -> void:
    _net_bridge = bridge
    _net_bridge.dispatcher = _dispatcher
    _dispatcher.net_bridge = bridge

## Sets the callable invoked when a [code]replicate()[/code] command succeeds. The callable receives [code](command_name: String, result: QTIResult)[/code]. Requires [method attach_net_bridge] to have been called first.
func set_replication_handler(callable: Callable) -> void:
    if _net_bridge == null:
        push_error("QTICommand: set_replication_handler() called before attach_net_bridge(). Add a QTINetBridge to the scene tree and call QTICommand.attach_net_bridge(bridge) first.")
        return
    _net_bridge.set_replication_handler(callable)

## Enables or disables the built-in commands ([code]help[/code], [code]list[/code], [code]history[/code], [code]clear[/code], [code]alias[/code]). Built-ins are enabled by default; call with [code]false[/code] to remove them.
func enable_builtins(enabled: bool) -> void:
    _builtins_enabled = enabled
    if enabled and not _builtins_registered:
        QTIBuiltinCommands.register_all(self)
        _builtins_registered = true
    elif not enabled and _builtins_registered:
        QTIBuiltinCommands.unregister_all(self)
        _builtins_registered = false

## Dispatches [param raw_input] without recording history. Signals are suppressed by default; pass [code]{"emit_signals": true}[/code] in [param opts] to forward them. Useful for unit tests or editor tooling.
func simulate(raw_input: String, context: QTIContext, opts: Dictionary = {}) -> QTIResult:
    var emit_signals: bool = opts.get("emit_signals", false)
    if not emit_signals:
        return _dispatcher.dispatch(raw_input, context, false)
    _last_invoker_key = _dispatcher.invoker_key(context)
    return _dispatcher.dispatch(raw_input, context, true)
