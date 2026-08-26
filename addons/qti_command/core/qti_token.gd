## A single parsed token with its text and character-position span.
##
## Produced by [QTITokenizerUtil] (and [QTITokenizer], which delegates to it). The [member start]/[member end] offsets index into the original untokenized string, which is what lets [code]rest[/code] arguments capture their raw, unstripped remainder via [method QTITokenizerUtil.raw_remainder].
class_name QTIToken
extends RefCounted

## The unquoted token text.
var text: String
## Character index of the first character in the original input.
var start: int
## Character index one past the last character in the original input.
var end: int

func _init(p_text: String = "", p_start: int = 0, p_end: int = 0) -> void:
    text = p_text
    start = p_start
    end = p_end
