extends Node

func _ready() -> void:
    QTICommand.from_function(cmd_heal, "heal") \
        .description("Heal a target") \
        .category("Debug") \
        .execute(cmd_heal)

func cmd_heal(ctx: QTIContext, target: QTIPlayerRef, amount: int = 100) -> QTIResult:
    if target == null or target.value == null:
        return ctx.fail("No target resolved.", "runtime")
    if target.value.has_method("heal"):
        target.value.heal(amount)
    return ctx.ok("Healed %s for %d" % [target.matched_name, amount])
