## Maps type name strings to [QTIArgType] parser instances.
##
## Owned by [QTICommand] and pre-populated with all built-in types. Use [method QTICommand.register_type] and [method QTICommand.set_entity_source] rather than accessing this class directly.
class_name QTITypeRegistry
extends RefCounted

var _types: Dictionary = {}
var _entity_source: Callable = Callable()

func _init() -> void:
    _register_defaults()

func _register_defaults() -> void:
    register_type(QTIType.INT, QTIBuiltinTypes.IntType.new())
    register_type(QTIType.FLOAT, QTIBuiltinTypes.FloatType.new())
    register_type(QTIType.STRING, QTIBuiltinTypes.StringType.new())
    register_type(QTIType.BOOL, QTIBuiltinTypes.BoolType.new())
    register_type(QTIType.ENUM, QTIBuiltinTypes.EnumType.new())
    register_type(QTIType.VECTOR2, QTIGodotTypes.Vector2Type.new())
    register_type(QTIType.VECTOR3, QTIGodotTypes.Vector3Type.new())
    register_type(QTIType.COLOR, QTIGodotTypes.ColorType.new())
    register_type(QTIType.NODEPATH, QTIGodotTypes.NodePathType.new())
    register_type(QTIType.PLAYER_REF, QTIEntityTypes.PlayerRefType.new(self))
    register_type(QTIType.ENTITY_REF, QTIEntityTypes.EntityRefType.new(self))

## Registers [param parser] under [param type_name]. Overwrites any existing registration for that name.
func register_type(type_name: String, parser: QTIArgType) -> void:
    _types[type_name] = parser

## Returns [code]true[/code] if a parser is registered under [param type_name].
func has_type(type_name: String) -> bool:
    return _types.has(type_name)

## Delegates to the parser registered for [param type_name].
## Returns a runtime-error [QTIParseResult] if the type is unknown.
func parse(type_name: String, raw: String, ctx: QTIContext) -> QTIParseResult:
    if not _types.has(type_name):
        return QTIParseResult.fail("Unknown argument type '%s'." % type_name, "runtime")
    return _types[type_name].parse(raw, ctx)

## Delegates to the autocomplete implementation for [param type_name].
## Returns an empty array if the type is unknown or provides no suggestions.
func autocomplete(type_name: String, partial: String, ctx: QTIContext) -> Array[String]:
    if not _types.has(type_name):
        return []
    return _types[type_name].autocomplete(partial, ctx)

## Sets the callable used by entity-resolution types to obtain the candidate list. [param callable] must return an [code]Array[Node][/code].
func set_entity_source(callable: Callable) -> void:
    _entity_source = callable

## Returns [code]true[/code] if an entity source callable has been registered.
func has_entity_source() -> bool:
    return _entity_source.is_valid()

## Calls the entity source and returns its result, or an empty array if no source is registered or the source returns a non-Array value.
func get_entities() -> Array:
    if not _entity_source.is_valid():
        return []
    var result = _entity_source.call()
    if result is Array:
        return result
    return []

## Maps a Godot [enum Variant.Type] constant to the closest [QTIType] string. Falls back to [constant QTIType.STRING] for unmapped types.
static func godot_variant_type_to_qti_type(variant_type: int) -> String:
    match variant_type:
        TYPE_INT:
            return QTIType.INT
        TYPE_FLOAT:
            return QTIType.FLOAT
        TYPE_STRING, TYPE_STRING_NAME:
            return QTIType.STRING
        TYPE_BOOL:
            return QTIType.BOOL
        TYPE_VECTOR2:
            return QTIType.VECTOR2
        TYPE_VECTOR3:
            return QTIType.VECTOR3
        TYPE_COLOR:
            return QTIType.COLOR
        TYPE_NODE_PATH:
            return QTIType.NODEPATH
        _:
            return QTIType.STRING
