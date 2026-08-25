@tool
extends EditorPlugin

const AUTOLOAD_NAME := "QTICommand"
const AUTOLOAD_PATH := "res://addons/qti_command/autoload/qti_command.gd"

var _dock: Control = null

func _enter_tree() -> void:
    add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)
    _dock = preload("res://addons/qti_command/editor/qti_editor_dock.gd").new()
    _dock.name = "QTI Command"
    add_control_to_dock(EditorPlugin.DOCK_SLOT_LEFT_BR, _dock)

func _exit_tree() -> void:
    if _dock != null:
        remove_control_from_docks(_dock)
        _dock.queue_free()
        _dock = null
    remove_autoload_singleton(AUTOLOAD_NAME)
