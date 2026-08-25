## String constants for the built-in argument types.
##
## Pass these as the [param type] argument of [method QTICommandBuilder.arg]. Custom types registered via [method QTICommand.register_type] are identified by whatever string key you choose; these constants exist purely for readability and to avoid typo-prone literals.
class_name QTIType
extends RefCounted

## Integer ([int]).
const INT := "int"
## Floating-point number ([float]).
const FLOAT := "float"
## Arbitrary text ([String]). Quoted strings are supported.
const STRING := "string"
## Boolean ([bool]). Accepts [code]true/false[/code], [code]yes/no[/code], [code]1/0[/code], [code]on/off[/code].
const BOOL := "bool"
## Two-component vector parsed from [code]x,y[/code] or [code]x y[/code] ([Vector2]).
const VECTOR2 := "vector2"
## Three-component vector parsed from [code]x,y,z[/code] or [code]x y z[/code] ([Vector3]).
const VECTOR3 := "vector3"
## Colour parsed from a hex string ([code]#rrggbb[/code]) or a CSS named colour ([Color]).
const COLOR := "color"
## Godot [NodePath].
const NODEPATH := "nodepath"
## Comma-separated enum value — pass [code]one_of[/code] in opts to restrict choices.
const ENUM := "enum"
## Fuzzy-resolved player [Node]. Requires [method QTICommand.set_entity_source]. Resolves to a [QTIPlayerRef].
const PLAYER_REF := "player_ref"
## Fuzzy-resolved entity [Node]. Requires [method QTICommand.set_entity_source]. Resolves to a [QTIEntityRef].
const ENTITY_REF := "entity_ref"
