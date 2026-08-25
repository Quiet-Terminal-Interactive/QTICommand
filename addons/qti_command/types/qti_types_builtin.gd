class_name QTIBuiltinTypes
extends RefCounted

class IntType extends QTIArgType:
    func parse(raw: String, ctx: QTIContext) -> QTIParseResult:
        var s := raw.strip_edges()
        if not s.is_valid_int():
            return QTIParseResult.fail("Expected an integer, got '%s'." % raw)
        return QTIParseResult.ok(s.to_int())

class FloatType extends QTIArgType:
    func parse(raw: String, ctx: QTIContext) -> QTIParseResult:
        var s := raw.strip_edges()
        if not s.is_valid_float() and not s.is_valid_int():
            return QTIParseResult.fail("Expected a number, got '%s'." % raw)
        return QTIParseResult.ok(s.to_float())

class StringType extends QTIArgType:
    func parse(raw: String, ctx: QTIContext) -> QTIParseResult:
        return QTIParseResult.ok(raw)

class BoolType extends QTIArgType:
    const TRUE_VALUES := ["true", "1", "yes", "y", "on"]
    const FALSE_VALUES := ["false", "0", "no", "n", "off"]

    func parse(raw: String, ctx: QTIContext) -> QTIParseResult:
        var s := raw.strip_edges().to_lower()
        if TRUE_VALUES.has(s):
            return QTIParseResult.ok(true)
        if FALSE_VALUES.has(s):
            return QTIParseResult.ok(false)
        return QTIParseResult.fail("Expected a boolean (true/false/1/0/yes/no), got '%s'." % raw)

    func autocomplete(partial: String, ctx: QTIContext) -> Array[String]:
        var out: Array[String] = []
        for v in ["true", "false"]:
            if v.begins_with(partial.to_lower()):
                out.append(v)
        return out

class EnumType extends QTIArgType:
    func parse(raw: String, ctx: QTIContext) -> QTIParseResult:
        return QTIParseResult.ok(raw)
