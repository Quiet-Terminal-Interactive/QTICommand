extends Node

func _ready() -> void:
    _register_commands()

func _register_commands() -> void:
    QTICommand.register("teleport") \
        .description("Teleport to coordinates or a named location") \
        .category("World") \
        .alias("tp") \
        .arg("x", QTIType.FLOAT) \
        .arg("y", QTIType.FLOAT) \
        .arg("z", QTIType.FLOAT, {"optional": true, "default": 0.0}) \
        .permission("admin") \
        .cooldown(1.0) \
        .execute(func(ctx: QTIContext) -> QTIResult:
            var pos := Vector3(ctx.get("x"), ctx.get("y"), ctx.get("z"))
            if ctx.invoker is Node3D:
                ctx.invoker.global_position = pos
            return ctx.ok("Teleported to %s" % pos)
        )
