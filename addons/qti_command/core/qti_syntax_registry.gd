## Stores registered [QTISyntaxProvider]s and resolves which one is active for a given [QTIContext].
##
class_name QTISyntaxRegistry
extends RefCounted

var _providers: Dictionary = {}
var _default_syntax_name: String = QTISyntax.DEFAULT
var _default_syntax_options: Dictionary = {}
var _source_overrides: Dictionary = {}

func _init() -> void:
    register_syntax(QTISyntax.DEFAULT, QTISyntaxDefault.new())
    register_syntax(QTISyntax.BASH, QTISyntaxBash.new())
    register_syntax(QTISyntax.POWERSHELL, QTISyntaxPowerShell.new())

## Registers a custom [param provider] under [param name] (a [QTISyntax] constant or any custom string).
func register_syntax(name: String, provider: QTISyntaxProvider) -> void:
    _providers[name] = provider

## Sets the active syntax. If [param source_filter] contains a [code]"source"[/code] key, this becomes a per-source override for [code]ctx.source == source_filter.source[/code] (the remaining keys are passed to the provider as options); otherwise it sets the global default, with [param source_filter] (minus any [code]"source"[/code] key, which won't be present) passed as provider options.
func set_syntax(syntax: Variant, source_filter: Dictionary = {}) -> void:
    var name := String(syntax)
    if source_filter.has("source"):
        var opts := source_filter.duplicate()
        var source_key := String(opts["source"])
        opts.erase("source")
        _source_overrides[source_key] = {"name": name, "options": opts}
    else:
        _default_syntax_name = name
        _default_syntax_options = source_filter

## Resolves the active provider for [param ctx]: [member QTIContext.syntax_override] first (set by [QTITestContext.mock] to isolate tests from global config), then a per-source override matching [member QTIContext.source], then the global default.
func resolve_provider(ctx: QTIContext) -> QTISyntaxProvider:
    if ctx != null and ctx.syntax_override != null:
        return _get(String(ctx.syntax_override)).with_options(ctx.syntax_override_options)
    var source_key := String(ctx.source) if ctx != null else ""
    if _source_overrides.has(source_key):
        var o: Dictionary = _source_overrides[source_key]
        return _get(o["name"]).with_options(o.get("options", {}))
    return _get(_default_syntax_name).with_options(_default_syntax_options)

func _get(name: StringName) -> QTISyntaxProvider:
    if not _providers.has(name):
        push_error("QTICommand: unknown syntax '%s'; falling back to '%s'." % [name, QTISyntax.DEFAULT])
        return _providers[QTISyntax.DEFAULT]
    return _providers[name]
