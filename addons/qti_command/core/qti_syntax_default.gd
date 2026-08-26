## The reference [QTISyntaxProvider]
##
## Opt in to [code];[/code]-only sequence chaining with:
## [codeblock]
## QTICommand.set_syntax(QTISyntax.DEFAULT, {"allow_sequence_chaining": true})
## [/codeblock]
## [method supports_piping] stays [code]false[/code] regardless of this flag, piping is not part of this opt-in.
class_name QTISyntaxDefault
extends QTISyntaxProvider

## When [code]true[/code], [method split_chain] splits on quote-aware [code];[/code] (always-run [code]&"sequence"[/code] semantics; [code]&&[/code]/[code]||[/code] remain unavailable in this syntax, so there is no short-circuit case to handle).
var allow_sequence_chaining: bool = false

func get_name() -> String:
    return QTISyntax.DEFAULT

func with_options(options: Dictionary) -> QTISyntaxProvider:
    var p := QTISyntaxDefault.new()
    p.allow_sequence_chaining = options.get("allow_sequence_chaining", false)
    return p

func split_chain(raw_input: String) -> Array[QTIChainLink]:
    if not allow_sequence_chaining:
        return [QTIChainLink.new(raw_input, &"start", 0)]
    var matches := QTITokenizerUtil.split_on_quote_aware(raw_input, [";"])
    if matches.is_empty():
        return [QTIChainLink.new(raw_input, &"start", 0)]
    var links: Array[QTIChainLink] = []
    var cursor := 0
    var join_type := &"start"
    for m in matches:
        links.append(QTIChainLink.new(raw_input.substr(cursor, m["pos"] - cursor), join_type, cursor))
        cursor = m["end"]
        join_type = &"sequence"
    links.append(QTIChainLink.new(raw_input.substr(cursor), join_type, cursor))
    return links

func tokenize(segment: String) -> Array[QTIToken]:
    return QTITokenizerUtil.tokenize_quoted(segment)

func bind_arguments(tokens: Array[QTIToken], def: QTICommandDef, full_segment: String) -> QTIBindResult:
    return bind_positional_and_flags(tokens, def, full_segment)

func supports_piping() -> bool:
    return false

static func bind_positional_and_flags(tokens: Array[QTIToken], def: QTICommandDef, full_segment: String) -> QTIBindResult:
    var extraction := QTITokenizerUtil.extract_flags(tokens)
    var positional_tokens: Array = extraction["positional"]
    var flags_raw: Dictionary = extraction["flags"]

    var bound := {}
    for flag_name in flags_raw:
        bound[flag_name] = flags_raw[flag_name]

    var n := def.positional_args.size()
    var has_rest := false
    for i in range(n):
        var arg_def: QTIArgument = def.positional_args[i]
        var token: QTIToken = positional_tokens[i] if i < positional_tokens.size() else null
        if arg_def.rest:
            has_rest = true
            var raw := QTITokenizerUtil.raw_remainder(full_segment, token.start) if token != null else ""
            if raw != "":
                bound[arg_def.name] = raw
            continue
        if token != null:
            bound[arg_def.name] = token.text

    if not has_rest and positional_tokens.size() > n:
        return QTIBindResult.failure("Too many arguments for '%s'. Usage: %s" % [def.name, def.usage_string()])

    return QTIBindResult.ok(bound)
