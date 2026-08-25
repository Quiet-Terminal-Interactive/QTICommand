extends Node
## Stores per-invoker role lists and resolves permission checks against them. Every invoker starts with only the implicit "player" role. Roles are granted and revoked at runtime by the /grant and /revoke admin commands below.
class GamePermissionResolver extends QTIPermissionResolver:
    var _roles: Dictionary = {}

    func grant_role(invoker: Variant, role: String) -> void:
        var key := _key(invoker)
        if not _roles.has(key):
            _roles[key] = []
        if role not in _roles[key]:
            _roles[key].append(role)

    func revoke_role(invoker: Variant, role: String) -> void:
        var key := _key(invoker)
        if _roles.has(key):
            _roles[key].erase(role)

    func get_roles(invoker: Variant) -> Array:
        return _roles.get(_key(invoker), [])

    func has_permission(invoker: Variant, role: String) -> bool:
        if role == "player":
            return true
        return _roles.get(_key(invoker), []).has(role)

    func _key(invoker: Variant) -> String:
        if invoker is Object:
            return str(invoker.get_instance_id())
        return str(invoker)

var _permissions: GamePermissionResolver

@onready var console: QTIConsole = $QTIConsole


func _ready() -> void:
    _setup_permissions()
    _setup_entity_source()
    _setup_console()
    _register_commands()


func _setup_permissions() -> void:
    _permissions = GamePermissionResolver.new()
    QTICommand.set_permission_resolver(_permissions)


func _setup_entity_source() -> void:
    # PLAYER_REF and ENTITY_REF args use this callable to resolve names.
    # Return every node that should be matchable by name.
    QTICommand.set_entity_source(func() -> Array[Node]:
        return get_tree().get_nodes_in_group("players")
    )


func _setup_console() -> void:
    # Bind the local player as the console invoker so that permissions, cooldowns, and per-player history are evaluated for the right actor.
    var local_player: Node = get_tree().get_first_node_in_group("local_player")
    if local_player:
        console.invoker = local_player

    # Metadata is forwarded to every QTIContext the console creates.
    console.metadata = {"game_mode": "survival"}

    # Wire lifecycle signals to whatever logging/HUD you have.
    QTICommand.command_executed.connect(_on_command_executed)
    QTICommand.command_failed.connect(_on_command_failed)


func _on_command_executed(result: QTIResult) -> void:
    print("[CMD] %s -> %s" % [result.command_name, result.message])


func _on_command_failed(result: QTIResult) -> void:
    print("[CMD FAIL] %s (%s) -> %s" % [result.command_name, result.error_type, result.message])


func _register_commands() -> void:
    _register_basic_commands()
    _register_world_commands()
    _register_admin_commands()
    _register_permission_commands()


func _register_basic_commands() -> void:
    # Simplest possible command, no arguments.
    QTICommand.register("ping") \
        .description("Check that the console is responding") \
        .category("Utility") \
        .execute(func(ctx: QTIContext) -> QTIResult:
            return ctx.ok("pong")
        )

    # Optional STRING argument with a default value; compile-time alias /hi.
    QTICommand.register("greet") \
        .description("Print a greeting") \
        .category("Utility") \
        .alias("hi") \
        .arg("name", QTIType.STRING, {"optional": true, "default": "world"}) \
        .execute(func(ctx: QTIContext) -> QTIResult:
            return ctx.ok("Hello, %s!" % ctx.get("name"))
        )

    # Boolean flag: /status --verbose adds extra metrics.
    QTICommand.register("status") \
        .description("Show server status") \
        .category("Utility") \
        .flag("verbose", {"description": "Include detailed metrics"}) \
        .execute(func(ctx: QTIContext) -> QTIResult:
            var msg := "Server: online"
            if ctx.has("verbose"):
                msg += " | FPS: %d" % Engine.get_frames_per_second()
            return ctx.ok(msg)
        )

    # ctx.reply() streams multiple lines before the final result.
    QTICommand.register("whoami") \
        .description("Show your current invoker identity and roles") \
        .category("Utility") \
        .execute(func(ctx: QTIContext) -> QTIResult:
            ctx.reply("Invoker: %s" % str(ctx.invoker))
            ctx.reply("Source:  %s" % ctx.source)
            var roles: Array = _permissions.get_roles(ctx.invoker)
            ctx.reply("Roles:   %s" % (", ".join(roles) if roles else "player (default)"))
            return ctx.ok()
        )


func _register_world_commands() -> void:
    # Enum-style restriction via one_of; 2-second cooldown between uses.
    QTICommand.register("weather") \
        .description("Change the world weather") \
        .category("World") \
        .arg("type", QTIType.STRING, {"one_of": ["clear", "rain", "storm", "snow"]}) \
        .permission("moderator") \
        .cooldown(2.0) \
        .execute(func(ctx: QTIContext) -> QTIResult:
            var weather: String = ctx.get("type")
            # WorldManager.set_weather(weather)
            return ctx.ok("Weather set to '%s'" % weather)
        )

    # Numeric range validation via min/max opts.
    QTICommand.register("time") \
        .description("Set the in-game time of day (0–24)") \
        .category("World") \
        .arg("hour", QTIType.FLOAT, {"min": 0.0, "max": 24.0}) \
        .permission("moderator") \
        .execute(func(ctx: QTIContext) -> QTIResult:
            var hour: float = ctx.get("hour")
            # WorldManager.set_time(hour)
            return ctx.ok("Time set to %02d:%02d" % [int(hour), int(fmod(hour, 1.0) * 60.0)])
        )

    # PLAYER_REF resolves a name to a node via set_entity_source(). Multiple .permission() calls use OR logic: moderator OR admin may run this.
    QTICommand.register("teleport") \
        .description("Teleport a player to a position") \
        .category("World") \
        .alias("tp") \
        .arg("target", QTIType.PLAYER_REF) \
        .arg("x", QTIType.FLOAT) \
        .arg("y", QTIType.FLOAT) \
        .arg("z", QTIType.FLOAT, {"optional": true, "default": 0.0}) \
        .permission("moderator") \
        .permission("admin") \
        .cooldown(1.0) \
        .execute(func(ctx: QTIContext) -> QTIResult:
            var target: QTIPlayerRef = ctx.get("target")
            if target == null or target.value == null:
                return ctx.fail("No player found matching that name.")
            var pos := Vector3(ctx.get("x"), ctx.get("y"), ctx.get("z"))
            if target.value is Node3D:
                target.value.global_position = pos
            return ctx.ok("Teleported %s to %s" % [target.matched_name, pos])
        )

func _register_admin_commands() -> void:
    # rest: true lets the reason consume the rest of the input line as one string.
    QTICommand.register("kick") \
        .description("Kick a player from the server") \
        .category("Admin") \
        .arg("target", QTIType.PLAYER_REF) \
        .arg("reason", QTIType.STRING, {"optional": true, "default": "No reason given", "rest": true}) \
        .permission("admin") \
        .execute(func(ctx: QTIContext) -> QTIResult:
            var target: QTIPlayerRef = ctx.get("target")
            if target == null or target.value == null:
                return ctx.fail("Player not found.")
            # target.value.kick(ctx.get("reason"))
            return ctx.ok("Kicked %s: %s" % [target.matched_name, ctx.get("reason")])
        )

    # .validate() runs before .execute(); return a non-empty string to abort.
    QTICommand.register("setspeed") \
        .description("Override a player's movement speed") \
        .category("Admin") \
        .arg("target", QTIType.PLAYER_REF) \
        .arg("speed", QTIType.FLOAT) \
        .permission("admin") \
        .validate(func(ctx: QTIContext) -> String:
            var spd: float = ctx.get("speed")
            if spd < 0.0:
                return "Speed cannot be negative."
            if spd > 9999.0:
                return "Speed cap is 9999."
            return ""
        ) \
        .execute(func(ctx: QTIContext) -> QTIResult:
            var target: QTIPlayerRef = ctx.get("target")
            if target == null or target.value == null:
                return ctx.fail("Player not found.")
            # target.value.speed = ctx.get("speed")
            return ctx.ok("Set %s speed to %.1f" % [target.matched_name, ctx.get("speed")])
        )

    # .hidden() removes the command from /list and autocomplete for everyone.
    QTICommand.register("debug_dump") \
        .description("Dump internal state to output") \
        .category("Admin") \
        .permission("admin") \
        .hidden() \
        .execute(func(ctx: QTIContext) -> QTIResult:
            var cmds := QTICommand.list_commands()
            ctx.reply("Registered commands: %d" % cmds.size())
            for def in cmds:
                ctx.reply("  /%s — %s" % [def.name, def.description])
            return ctx.ok()
        )

func _register_permission_commands() -> void:
    QTICommand.register("grant") \
        .description("Give a player a role (moderator or admin)") \
        .category("Admin") \
        .arg("target", QTIType.PLAYER_REF) \
        .arg("role", QTIType.STRING, {"one_of": ["moderator", "admin"]}) \
        .permission("admin") \
        .execute(func(ctx: QTIContext) -> QTIResult:
            var target: QTIPlayerRef = ctx.get("target")
            if target == null or target.value == null:
                return ctx.fail("Player not found.")
            var role: String = ctx.get("role")
            _permissions.grant_role(target.value, role)
            return ctx.ok("Granted '%s' to %s" % [role, target.matched_name])
        )

    QTICommand.register("revoke") \
        .description("Remove a role from a player") \
        .category("Admin") \
        .arg("target", QTIType.PLAYER_REF) \
        .arg("role", QTIType.STRING, {"one_of": ["moderator", "admin"]}) \
        .permission("admin") \
        .execute(func(ctx: QTIContext) -> QTIResult:
            var target: QTIPlayerRef = ctx.get("target")
            if target == null or target.value == null:
                return ctx.fail("Player not found.")
            var role: String = ctx.get("role")
            _permissions.revoke_role(target.value, role)
            return ctx.ok("Revoked '%s' from %s" % [role, target.matched_name])
        )
