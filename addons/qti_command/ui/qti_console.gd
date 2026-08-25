## Drop-in in-game console UI for QTI Command.
##
## Add [QTIConsole] to your scene and it will wire itself to the [QTICommand] autoload. Press the backtick key ([code]`[/code]) or fire the [code]qti_toggle_console[/code] input action to show/hide it. The action is registered automatically if it does not already exist.
## [br][br]
## Set [member invoker] to the player object (or peer ID, etc.) so that history, permissions, and cooldowns are evaluated for the correct invoker. Override [member theme_resource] in the Inspector to skin the panel.
class_name QTIConsole
extends Control

## Optional [Theme] resource applied to the console root control. Populate with your style-box, font, and colour overrides.
@export var theme_resource: Theme

## The invoker passed to every [QTIContext] created by this console. Set this to your local player node or peer ID before the player can type.
var invoker: Variant = null
## Arbitrary metadata merged into every [QTIContext] created by this console.
var metadata: Dictionary = {}

var _input_line: LineEdit
var _output_container: VBoxContainer
var _scroll: ScrollContainer
var _autocomplete: QTIAutocompletePanel
var _history_index: int = -1

func _ready() -> void:
    visible = false
    _ensure_input_action()
    _build_ui()
    if theme_resource:
        theme = theme_resource

func _ensure_input_action() -> void:
    if InputMap.has_action("qti_toggle_console"):
        return
    InputMap.add_action("qti_toggle_console")
    var ev := InputEventKey.new()
    ev.keycode = KEY_QUOTELEFT
    InputMap.action_add_event("qti_toggle_console", ev)

func _build_ui() -> void:
    set_anchors_preset(Control.PRESET_TOP_WIDE)

    var panel := PanelContainer.new()
    panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
    add_child(panel)

    var vbox := VBoxContainer.new()
    panel.add_child(vbox)

    _scroll = ScrollContainer.new()
    _scroll.custom_minimum_size = Vector2(0, 300)
    vbox.add_child(_scroll)

    _output_container = VBoxContainer.new()
    _output_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _scroll.add_child(_output_container)

    _input_line = LineEdit.new()
    _input_line.placeholder_text = "%s command..." % QTICommand.get_prefix()
    _input_line.text_submitted.connect(_on_submitted)
    _input_line.gui_input.connect(_on_input_gui_input)
    vbox.add_child(_input_line)

    _autocomplete = QTIAutocompletePanel.new()
    add_child(_autocomplete)
    _autocomplete.suggestion_chosen.connect(_on_suggestion_chosen)

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("qti_toggle_console"):
        toggle()
        get_viewport().set_input_as_handled()

## Toggles console visibility. Grabs input focus when shown.
func toggle() -> void:
    visible = not visible
    if visible:
        _input_line.grab_focus()

func _on_input_gui_input(event: InputEvent) -> void:
    if not (event is InputEventKey) or not event.pressed:
        return
    var key_event: InputEventKey = event
    match key_event.keycode:
        KEY_UP:
            _cycle_history(-1)
            accept_event()
        KEY_DOWN:
            _cycle_history(1)
            accept_event()
        KEY_TAB:
            _do_autocomplete()
            accept_event()

func _cycle_history(direction: int) -> void:
    var history := QTICommand.get_history()
    var key := str(invoker.get_instance_id()) if invoker is Object else str(invoker)
    var entries := history.get_recent(50, key)
    if entries.is_empty():
        return
    _history_index = clampi(_history_index + direction, 0, entries.size() - 1)
    _input_line.text = entries[entries.size() - 1 - _history_index].raw_input
    _input_line.caret_column = _input_line.text.length()

func _do_autocomplete() -> void:
    var suggestions := QTICommand.autocomplete(_input_line.text, _make_context())
    _autocomplete.show_suggestions(suggestions)

func _on_suggestion_chosen(text: String) -> void:
    _input_line.text = text + " "
    _input_line.caret_column = _input_line.text.length()
    _input_line.grab_focus()

func _make_context() -> QTIContext:
    var ctx := QTIContext.new()
    ctx.invoker = invoker
    ctx.source = &"console"
    ctx.metadata = metadata.duplicate()
    ctx.replied.connect(_append_line_message)
    return ctx

func _on_submitted(text: String) -> void:
    if text.strip_edges() == "":
        return
    var result := QTICommand.dispatch(text, _make_context())
    if result.handled:
        _append_line_result(result)
        if result.data.get("ui_action", "") == "clear":
            _clear_output()
    else:
        _append_line_message("[color=gray]Unknown command.[/color]")
    _input_line.text = ""
    _history_index = -1

func _append_line_result(result: QTIResult) -> void:
    var line := QTIOutputLine.new()
    _output_container.add_child(line)
    line.display_result(result)
    _scroll_to_bottom()

func _append_line_message(message: String) -> void:
    var line := QTIOutputLine.new()
    _output_container.add_child(line)
    line.display_message(message)
    _scroll_to_bottom()

func _clear_output() -> void:
    for child in _output_container.get_children():
        child.queue_free()

func _scroll_to_bottom() -> void:
    await get_tree().process_frame
    _scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)
