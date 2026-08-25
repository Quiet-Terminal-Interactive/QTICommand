## A single output line in the console, rendered as BBCode-enabled rich text.
##
## Instantiated and populated by [QTIConsole] after each dispatch. Supports table output (via [code]data["headers"][/code] + [code]data["rows"][/code]) and clickable command links (any [code]meta[/code] that starts with the active prefix).
class_name QTIOutputLine
extends RichTextLabel

func _ready() -> void:
    bbcode_enabled = true
    fit_content = true
    scroll_active = false
    autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    meta_clicked.connect(_on_meta_clicked)

## Renders [param result] as coloured BBCode text. Success results are white; failures are red. When [member QTIResult.data] contains [code]"headers"[/code] and [code]"rows"[/code] keys, a BBCode table is appended below the message.
func display_result(result: QTIResult) -> void:
    var out := ""
    if result.message != "":
        var color := "white" if result.success else "red"
        out += "[color=%s]%s[/color]" % [color, result.message]
    if result.data.has("headers") and result.data.has("rows"):
        if out != "":
            out += "\n"
        out += _render_table(result.data["headers"], result.data["rows"])
    text = out

## Renders [param message] as raw BBCode text without any colouring applied.
func display_message(message: String) -> void:
    text = message

func _render_table(headers: Array, rows: Array) -> String:
    var bb := "[table=%d]" % maxi(1, headers.size())
    for h in headers:
        bb += "[cell][b]%s[/b][/cell]" % str(h)
    for row in rows:
        for cell in row:
            bb += "[cell]%s[/cell]" % str(cell)
    bb += "[/table]"
    return bb

func _on_meta_clicked(meta: Variant) -> void:
    var command := str(meta)
    if not command.begins_with(QTICommand.get_prefix()):
        return
    var ctx := QTIContext.new()
    ctx.source = &"console"
    QTICommand.dispatch(command, ctx)
