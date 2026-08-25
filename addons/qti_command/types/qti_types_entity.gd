class_name QTIEntityTypes
extends RefCounted

const NO_SOURCE_MESSAGE := "QTICommand setup error: no entity source registered. Call QTICommand.set_entity_source(callable) before using PLAYER_REF/ENTITY_REF arguments. See docs/README.md#entity-resolution."
const FUZZY_THRESHOLD := 2

static func _resolve(raw: String, type_registry: QTITypeRegistry) -> QTIParseResult:
    if not type_registry.has_entity_source():
        return QTIParseResult.fail(NO_SOURCE_MESSAGE, "runtime")

    var query := raw.strip_edges()
    if query == "":
        return QTIParseResult.fail("Expected an entity name, got an empty value.")
    var query_lower := query.to_lower()
    var candidates: Array = type_registry.get_entities()

    for n in candidates:
        if str(n.name).to_lower() == query_lower:
            return QTIParseResult.ok(n)

    var prefix_matches: Array = []
    for n in candidates:
        if str(n.name).to_lower().begins_with(query_lower):
            prefix_matches.append(n)
    if prefix_matches.size() == 1:
        return QTIParseResult.ok(prefix_matches[0])
    if prefix_matches.size() > 1:
        return _ambiguous(raw, prefix_matches)

    var fuzzy_matches: Array = []
    for n in candidates:
        if _levenshtein(query_lower, str(n.name).to_lower()) <= FUZZY_THRESHOLD:
            fuzzy_matches.append(n)
    if fuzzy_matches.size() == 1:
        return QTIParseResult.ok(fuzzy_matches[0])
    if fuzzy_matches.size() > 1:
        return _ambiguous(raw, fuzzy_matches)

    return QTIParseResult.fail("No entity matching '%s'." % raw, "validation")

static func _ambiguous(raw: String, matches: Array) -> QTIParseResult:
    var names: Array[String] = []
    for n in matches:
        names.append(str(n.name))
    return QTIParseResult.fail("Did you mean: %s?" % ", ".join(names), "validation", {"candidates": names})

static func _levenshtein(a: String, b: String) -> int:
    var la := a.length()
    var lb := b.length()
    if la == 0:
        return lb
    if lb == 0:
        return la
    var prev: Array[int] = []
    for j in range(lb + 1):
        prev.append(j)
    for i in range(1, la + 1):
        var cur: Array[int] = [i]
        for j in range(1, lb + 1):
            var cost := 0 if a[i - 1] == b[j - 1] else 1
            cur.append(mini(mini(cur[j - 1] + 1, prev[j] + 1), prev[j - 1] + cost))
        prev = cur
    return prev[lb]

class PlayerRefType extends QTIArgType:
    var _type_registry: QTITypeRegistry

    func _init(p_type_registry: QTITypeRegistry) -> void:
        _type_registry = p_type_registry

    func parse(raw: String, ctx: QTIContext) -> QTIParseResult:
        var result := QTIEntityTypes._resolve(raw, _type_registry)
        if not result.success:
            return result
        return QTIParseResult.ok(QTIPlayerRef.new(result.value, str(result.value.name)))

    func autocomplete(partial: String, ctx: QTIContext) -> Array[String]:
        if not _type_registry.has_entity_source():
            return []
        var out: Array[String] = []
        var lower := partial.to_lower()
        for n in _type_registry.get_entities():
            var nm := str(n.name)
            if nm.to_lower().begins_with(lower):
                out.append(nm)
        return out

class EntityRefType extends QTIArgType:
    var _type_registry: QTITypeRegistry

    func _init(p_type_registry: QTITypeRegistry) -> void:
        _type_registry = p_type_registry

    func parse(raw: String, ctx: QTIContext) -> QTIParseResult:
        var result := QTIEntityTypes._resolve(raw, _type_registry)
        if not result.success:
            return result
        return QTIParseResult.ok(QTIEntityRef.new(result.value, str(result.value.name)))

    func autocomplete(partial: String, ctx: QTIContext) -> Array[String]:
        if not _type_registry.has_entity_source():
            return []
        var out: Array[String] = []
        var lower := partial.to_lower()
        for n in _type_registry.get_entities():
            var nm := str(n.name)
            if nm.to_lower().begins_with(lower):
                out.append(nm)
        return out
