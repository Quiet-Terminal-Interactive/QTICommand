## Popup panel that displays and cycles through autocomplete suggestions.
##
## Used internally by [QTIConsole]. Connect [signal suggestion_chosen] to insert the selected suggestion into the input field.
class_name QTIAutocompletePanel
extends PopupPanel

## Emitted when the user clicks an item in the suggestion list. [param text] is the full suggestion string (prefix included).
signal suggestion_chosen(text: String)

var _list: ItemList
var _suggestions: Array[String] = []
var _index: int = -1

func _ready() -> void:
    _list = ItemList.new()
    _list.select_mode = ItemList.SELECT_SINGLE
    _list.item_selected.connect(_on_item_selected)
    add_child(_list)

## Replaces the suggestion list with [param suggestions] and shows the popup. Hides the popup automatically when [param suggestions] is empty.
func show_suggestions(suggestions: Array[String]) -> void:
    _suggestions = suggestions
    _list.clear()
    for s in suggestions:
        _list.add_item(s)
    _index = -1
    if suggestions.is_empty():
        hide()
    else:
        popup()

## Advances the selection by one and returns the newly selected suggestion string.
func cycle_next() -> String:
    if _suggestions.is_empty():
        return ""
    _index = (_index + 1) % _suggestions.size()
    _list.select(_index)
    return _suggestions[_index]

## Retreats the selection by one and returns the newly selected suggestion string.
func cycle_prev() -> String:
    if _suggestions.is_empty():
        return ""
    _index = (_index - 1 + _suggestions.size()) % _suggestions.size()
    _list.select(_index)
    return _suggestions[_index]

## Returns the currently highlighted suggestion, or [code]""[/code] when nothing is selected.
func current() -> String:
    if _index < 0 or _index >= _suggestions.size():
        return ""
    return _suggestions[_index]

func _on_item_selected(index: int) -> void:
    _index = index
    suggestion_chosen.emit(_suggestions[index])
