extends Node

@onready var chat_log = get_node("../ChatLog")

func _on_chat_message_sent(text: String, sender) -> void:
    if text.begins_with(QTICommand.get_prefix()):
        var ctx := QTIContext.new()
        ctx.invoker = sender
        ctx.source = &"chat"
        var result := QTICommand.dispatch(text, ctx)
        if result.handled:
            if result.success:
                chat_log.add_system_message(result.message)
            else:
                chat_log.add_error_message(result.message)
            return
    chat_log.add_player_message(sender, text)
