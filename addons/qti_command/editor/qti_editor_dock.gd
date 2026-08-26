## Editor dock that provides an isolated QTI Command console inside the Godot editor.
##
## Added automatically to the bottom-left dock slot when the plugin is enabled. Uses its own private [QTIRegistry] and [QTIDispatcher] so editor commands do not interfere with runtime commands registered by your game.
## [br][br]
## Register editor-only commands with [method register_editor_command].
@tool
class_name QTIEditorDock
extends Control

var _registry: QTIRegistry
var _type_registry: QTITypeRegistry
var _syntax_registry: QTISyntaxRegistry
var _dispatcher: QTIDispatcher
var _input_line: LineEdit
var _output: RichTextLabel

func _ready() -> void:
    _type_registry = QTITypeRegistry.new()
    _registry = QTIRegistry.new(_type_registry)
    _syntax_registry = QTISyntaxRegistry.new()
    _dispatcher = QTIDispatcher.new(_registry, _type_registry, QTIPermissionResolver.new(), _syntax_registry)
    _build_ui()

## Returns a [QTICommandBuilder] for registering a command scoped to the editor dock. Editor commands are completely separate from runtime commands and only run inside the editor, not in a playing game.
func register_editor_command(name: String) -> QTICommandBuilder:
    return QTICommandBuilder.new(name, _registry)

func _build_ui() -> void:
    var vbox := VBoxContainer.new()
    vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(vbox)

    _output = RichTextLabel.new()
    _output.bbcode_enabled = true
    _output.custom_minimum_size = Vector2(0, 240)
    _output.size_flags_vertical = Control.SIZE_EXPAND_FILL
    vbox.add_child(_output)

    _input_line = LineEdit.new()
    _input_line.placeholder_text = "Run editor command..."
    _input_line.text_submitted.connect(_on_submitted)
    vbox.add_child(_input_line)

func _on_submitted(text: String) -> void:
    if text.strip_edges() == "":
        return

    var body := text.strip_edges()
    if _dispatcher.prefix != "" and body.begins_with(_dispatcher.prefix):
        body = body.substr(_dispatcher.prefix.length())
    var first_token := body.split(" ")[0] if body != "" else ""
    var def := _registry.get_command(first_token)

    if def != null and def.is_server_only:
        _append("[color=orange]'%s' is server-only and cannot run in the editor (no running game/network context).[/color]" % def.name)
        _input_line.text = ""
        return

    var ctx := QTIContext.new()
    ctx.invoker = self
    ctx.source = &"editor"
    var result := _dispatcher.dispatch(text, ctx, false)
    if not result.handled:
        _append("[color=gray]Unknown editor command.[/color]")
    else:
        var color := "white" if result.success else "red"
        _append("[color=%s]%s[/color]" % [color, result.message])
    _input_line.text = ""

func _append(bbcode_line: String) -> void:
    _output.append_text(bbcode_line + "\n")
