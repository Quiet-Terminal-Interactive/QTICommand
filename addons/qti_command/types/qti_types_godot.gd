class_name QTIGodotTypes
extends RefCounted

static func _split_components(raw: String) -> PackedStringArray:
    var s := raw.strip_edges()
    if s.find(",") != -1:
        return s.split(",")
    return s.split(" ", false)

static func _to_floats(parts: PackedStringArray):
    var out: Array[float] = []
    for p in parts:
        var t := p.strip_edges()
        if not t.is_valid_float() and not t.is_valid_int():
            return null
        out.append(t.to_float())
    return out

class Vector2Type extends QTIArgType:
    func parse(raw: String, ctx: QTIContext) -> QTIParseResult:
        var parts := QTIGodotTypes._split_components(raw)
        if parts.size() != 2:
            return QTIParseResult.fail("Expected a Vector2 as 'x,y' or 'x y', got '%s'." % raw)
        var nums = QTIGodotTypes._to_floats(parts)
        if nums == null:
            return QTIParseResult.fail("Vector2 components must be numbers, got '%s'." % raw)
        return QTIParseResult.ok(Vector2(nums[0], nums[1]))

class Vector3Type extends QTIArgType:
    func parse(raw: String, ctx: QTIContext) -> QTIParseResult:
        var parts := QTIGodotTypes._split_components(raw)
        if parts.size() != 3:
            return QTIParseResult.fail("Expected a Vector3 as 'x,y,z' or 'x y z', got '%s'." % raw)
        var nums = QTIGodotTypes._to_floats(parts)
        if nums == null:
            return QTIParseResult.fail("Vector3 components must be numbers, got '%s'." % raw)
        return QTIParseResult.ok(Vector3(nums[0], nums[1], nums[2]))

class ColorType extends QTIArgType:
    const NAMED_COLORS := {
        "red": Color.RED, "green": Color.GREEN, "blue": Color.BLUE,
        "white": Color.WHITE, "black": Color.BLACK, "yellow": Color.YELLOW,
        "cyan": Color.CYAN, "magenta": Color.MAGENTA, "orange": Color.ORANGE,
        "purple": Color.PURPLE, "pink": Color.PINK, "gray": Color.GRAY,
        "grey": Color.GRAY, "brown": Color.BROWN, "transparent": Color.TRANSPARENT,
    }

    func parse(raw: String, ctx: QTIContext) -> QTIParseResult:
        var s := raw.strip_edges()
        if s.find(",") != -1:
            var parts := s.split(",")
            if parts.size() < 3 or parts.size() > 4:
                return QTIParseResult.fail("Expected a Color as 'r,g,b' or 'r,g,b,a', got '%s'." % raw)
            var nums: Array[float] = []
            for p in parts:
                var t := p.strip_edges()
                if not t.is_valid_float() and not t.is_valid_int():
                    return QTIParseResult.fail("Color components must be numbers, got '%s'." % raw)
                nums.append(t.to_float())
            var a: float = nums[3] if nums.size() == 4 else 1.0
            return QTIParseResult.ok(Color(nums[0], nums[1], nums[2], a))
        var lower := s.to_lower()
        if NAMED_COLORS.has(lower):
            return QTIParseResult.ok(NAMED_COLORS[lower])
        if Color.html_is_valid(s):
            return QTIParseResult.ok(Color.html(s))
        return QTIParseResult.fail("Unrecognized color '%s'. Use hex (#ff0000), a named color, or 'r,g,b[,a]'." % raw)

    func autocomplete(partial: String, ctx: QTIContext) -> Array[String]:
        var out: Array[String] = []
        var lower := partial.to_lower()
        for name in NAMED_COLORS.keys():
            if name.begins_with(lower):
                out.append(name)
        return out

class NodePathType extends QTIArgType:
    func parse(raw: String, ctx: QTIContext) -> QTIParseResult:
        if raw.strip_edges() == "":
            return QTIParseResult.fail("Expected a NodePath, got an empty value.")
        return QTIParseResult.ok(NodePath(raw))
