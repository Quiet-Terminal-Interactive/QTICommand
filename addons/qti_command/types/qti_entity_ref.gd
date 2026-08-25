## Wraps a resolved entity [Node] and the name string that matched it.
##
## Returned by [constant QTIType.ENTITY_REF] arguments. Access the resolved node via [member value] and the matched display name via [member matched_name].
## [br][br]
## See also [QTIPlayerRef] for the player-specific subtype.
class_name QTIEntityRef
extends RefCounted

## The resolved [Node]. [code]null[/code] if resolution failed (this should not reach a command handler — failed resolution returns an error result instead).
var value: Node = null
## The candidate name string that was matched (exact, prefix, or fuzzy).
var matched_name: String = ""

func _init(p_value: Node = null, p_matched_name: String = "") -> void:
    value = p_value
    matched_name = p_matched_name
