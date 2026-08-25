## Stores and looks up registered [QTICommandDef] objects.
##
## Managed internally by [QTICommand]. You generally interact with it indirectly through [QTICommandBuilder.execute] and [method QTICommand.unregister].
class_name QTIRegistry
extends RefCounted

## Emitted whenever a new command is successfully registered.
signal command_registered(def: QTICommandDef)

## The type registry used to emit entity-source warnings at registration time.
var type_registry: QTITypeRegistry

var _commands: Dictionary = {}
var _alias_map: Dictionary = {}
var _runtime_aliases: Dictionary = {}

func _init(p_type_registry: QTITypeRegistry = null) -> void:
    type_registry = p_type_registry

## Registers [param def] and all its aliases. Emits [signal command_registered]. Existing entries under the same name are silently overwritten.
func register_command(def: QTICommandDef) -> void:
    _commands[def.name] = def
    for a in def.aliases:
        _alias_map[a] = def.name
    _warn_if_missing_entity_source(def)
    command_registered.emit(def)

## Removes the command named [param name] and its compile-time aliases. No-op if the command does not exist.
func unregister_command(name: String) -> void:
    if not _commands.has(name):
        return
    var def: QTICommandDef = _commands[name]
    for a in def.aliases:
        _alias_map.erase(a)
    _commands.erase(name)

## Returns the [QTICommandDef] for [param name] (or an alias), or [code]null[/code].
func get_command(name: String) -> QTICommandDef:
    if _commands.has(name):
        return _commands[name]
    if _alias_map.has(name):
        return _commands.get(_alias_map[name])
    return null

## Returns [code]true[/code] if a command or alias named [param name] is registered.
func has_command(name: String) -> bool:
    return _commands.has(name) or _alias_map.has(name)

## Returns the command string that [param name] expands to, or [code]""[/code] if [param name] is not a runtime alias.
func resolve_runtime_alias(name: String) -> String:
    return _runtime_aliases.get(name, "")

## Maps the runtime alias [param name] to the expansion [param command_string]. Overwrites any previous mapping for the same name.
func set_runtime_alias(name: String, command_string: String) -> void:
    _runtime_aliases[name] = command_string

## Returns all registered commands as a flat array (aliases excluded).
func list_all() -> Array[QTICommandDef]:
    var out: Array[QTICommandDef] = []
    for def in _commands.values():
        out.append(def)
    return out

func _warn_if_missing_entity_source(def: QTICommandDef) -> void:
    if type_registry == null or type_registry.has_entity_source():
        return
    for a in def.positional_args + def.flags:
        if a.type == QTIType.PLAYER_REF or a.type == QTIType.ENTITY_REF:
            push_error("QTICommand: command '%s' registers a %s argument ('%s') but no entity source has been set yet. Call QTICommand.set_entity_source(callable) before this command is dispatched. See docs/README.md#entity-resolution." % [def.name, a.type, a.name])
            return
