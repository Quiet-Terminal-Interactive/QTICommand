class_name QTIBuiltinCommands
extends RefCounted

const NAMES := ["help", "list", "history", "clear", "alias"]

static func register_all(qti) -> void:
    qti.register("help") \
        .description("List all commands, or show usage for one command.") \
        .category("Core") \
        .arg("command", QTIType.STRING, {"optional": true}) \
        .execute(func(ctx: QTIContext) -> QTIResult:
            return QTIBuiltinCommands._cmd_help(qti, ctx, false)
    )

    qti.register("list") \
        .description("List all commands as a table.") \
        .category("Core") \
        .arg("command", QTIType.STRING, {"optional": true}) \
        .execute(func(ctx: QTIContext) -> QTIResult:
            return QTIBuiltinCommands._cmd_help(qti, ctx, true)
    )

    qti.register("history") \
        .description("Show your recent command history.") \
        .category("Core") \
        .arg("n", QTIType.INT, {"optional": true, "default": 20}) \
        .execute(func(ctx: QTIContext) -> QTIResult:
            return QTIBuiltinCommands._cmd_history(qti, ctx)
    )

    qti.register("clear") \
        .description("Clear the console output (UI-only; no-op headless).") \
        .category("Core") \
        .execute(func(ctx: QTIContext) -> QTIResult:
            var result := ctx.ok("")
            result.data["ui_action"] = "clear"
            return result
    )

    qti.register("alias") \
        .description("Define a runtime alias for a command.") \
        .category("Core") \
        .arg("name", QTIType.STRING) \
        .arg("command", QTIType.STRING, {"rest": true}) \
        .execute(func(ctx: QTIContext) -> QTIResult:
            var alias_name: String = ctx.get("name")
            var target: String = ctx.get("command")
            qti.set_runtime_alias(alias_name, target)
            return ctx.ok("Alias '%s' -> '%s' registered." % [alias_name, target])
    )

static func unregister_all(qti) -> void:
    for n in NAMES:
        qti.unregister(n)

static func _cmd_history(qti, ctx: QTIContext) -> QTIResult:
    var history: QTIHistory = qti.get_history()
    var key := str(ctx.invoker.get_instance_id()) if ctx.invoker is Object else str(ctx.invoker)
    var entries := history.get_recent(ctx.get("n"), key)
    if entries.is_empty():
        return ctx.ok("No history yet.")
    var lines: Array[String] = []
    var rows := []
    for e in entries:
        var status := "OK" if e.success else "FAIL"
        var color := "green" if e.success else "red"
        lines.append("[color=%s]%s[/color] %s" % [color, status, e.raw_input])
        rows.append([status, e.raw_input])
    return ctx.ok("\n".join(lines), {"headers": ["status", "command"], "rows": rows})

static func _cmd_help(qti, ctx: QTIContext, as_table: bool) -> QTIResult:
    var target = ctx.get("command")
    if target != null and target != "":
        var def: QTICommandDef = qti.get_command(target)
        if def == null:
            return ctx.fail("No such command '%s'." % target, "not_found")
        var msg := "[b]%s[/b] — %s\nUsage: %s" % [def.name, def.description, def.usage_string()]
        if not def.aliases.is_empty():
            msg += "\nAliases: %s" % ", ".join(def.aliases)
        return ctx.ok(msg)

    var commands: Array[QTICommandDef] = qti.list_commands(ctx)
    var categories := {}
    var category_order: Array[String] = []
    for def in commands:
        var cat: String = def.category if def.category != "" else "General"
        if not categories.has(cat):
            categories[cat] = []
            category_order.append(cat)
        categories[cat].append(def)

    if as_table:
        var rows := []
        for cat in category_order:
            for def in categories[cat]:
                rows.append([def.name, cat, def.description])
        return ctx.ok("", {"headers": ["command", "category", "description"], "rows": rows})

    var lines: Array[String] = []
    for cat in category_order:
        lines.append("[b]%s[/b]" % cat)
        for def in categories[cat]:
            lines.append("  %s — %s" % [def.name, def.description])
    return ctx.ok("\n".join(lines))
