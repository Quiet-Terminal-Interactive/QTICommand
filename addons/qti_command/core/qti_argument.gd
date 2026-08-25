## Descriptor for a single positional argument or boolean flag on a command.
##
## Created by [method QTICommandBuilder.arg] and [method QTICommandBuilder.flag].
## Stored in [member QTICommandDef.positional_args] and [member QTICommandDef.flags].
class_name QTIArgument
extends RefCounted

## Argument identifier. Used as the key in [method QTIContext.get].
var name: String = ""
## Type string used for parsing. One of the [QTIType] constants or a custom registered type.
var type: String = ""
## When [code]true[/code], the argument may be omitted from input.
var optional: bool = false
## Value substituted when an optional argument is absent.
var default: Variant = null
## [code]true[/code] when a [member default] was explicitly provided.
var has_default: bool = false
## When [code]true[/code], this argument consumes all remaining input as a raw string. Only meaningful on the last positional argument.
var rest: bool = false
## Inclusive lower bound for numeric types. [code]null[/code] means no minimum.
var min_value = null
## Inclusive upper bound for numeric types. [code]null[/code] means no maximum.
var max_value = null
## ECMAScript-compatible regex pattern the string value must match. Empty string disables.
var regex: String = ""
## Explicit whitelist of allowed values. Empty array disables.
var one_of: Array = []
## Minimum string length. [code]-1[/code] disables.
var min_length: int = -1
## Maximum string length. [code]-1[/code] disables.
var max_length: int = -1
## [code]true[/code] for [code]--name[/code] flags; [code]false[/code] for positional arguments.
var is_flag: bool = false

func _init(p_name: String = "", p_type: String = "", opts: Dictionary = {}) -> void:
	name = p_name
	type = p_type
	optional = opts.get("optional", false)
	if opts.has("default"):
		default = opts["default"]
		has_default = true
		optional = true
	rest = opts.get("rest", false)
	if opts.has("min"):
		min_value = opts["min"]
	if opts.has("max"):
		max_value = opts["max"]
	regex = opts.get("regex", "")
	one_of = opts.get("one_of", [])
	min_length = opts.get("min_length", -1)
	max_length = opts.get("max_length", -1)
