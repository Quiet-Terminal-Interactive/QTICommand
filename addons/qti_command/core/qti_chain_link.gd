## One command's raw text within a chain, and how it relates to the previous link.
##
## Produced by [method QTISyntaxProvider.split_chain]. A non-chaining split returns a single link with [member join_type] [code]&"start"[/code].
class_name QTIChainLink
extends RefCounted

## Raw text for this one command, pre-tokenize.
var segment: String = ""
## How this link relates to the PREVIOUS link: [code]&"start"[/code] (first link, no relation), [code]&"and"[/code] ([code]&&[/code]), [code]&"or"[/code] ([code]||[/code]), [code]&"sequence"[/code] ([code];[/code]), or [code]&"pipe"[/code] ([code]|[/code]).
var join_type: StringName = &"start"
## Character offset of [member segment] within the string passed to [method QTISyntaxProvider.split_chain], before any per-link whitespace trimming. Used to reconstruct a "prelude" string for chain-aware autocomplete.
var start: int = 0

func _init(p_segment: String = "", p_join_type: StringName = &"start", p_start: int = 0) -> void:
    segment = p_segment
    join_type = p_join_type
    start = p_start
