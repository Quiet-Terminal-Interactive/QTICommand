## PowerShell-flavored [QTISyntaxProvider]: named parameters ([code]-Target john -Amount 100[/code], mixed with positional filling), [code];[/code] chaining, [code]|[/code] piping, [code]$var[/code] substitution. This implements PowerShell-flavored syntax only, not PowerShell's full type system ([code][CmdletBinding()][/code], real typed pipelines, etc.)
class_name QTISyntaxPowerShell
extends QTISyntaxProvider

const _OPERATORS: Array[String] = [";", "|"]
const _JOIN_TYPES := {
    ";": &"sequence",
    "|": &"pipe",
}

func get_name() -> String:
    return QTISyntax.POWERSHELL

func prepare_segment(segment: String, ctx: QTIContext) -> String:
    return QTITokenizerUtil.substitute_variables(segment, ctx, {"single_quote_literal": true})

func split_chain(raw_input: String) -> Array[QTIChainLink]:
    var matches := QTITokenizerUtil.split_on_quote_aware(raw_input, _OPERATORS, {"single_quote_literal": true})
    if matches.is_empty():
        return [QTIChainLink.new(raw_input, &"start", 0)]
    var links: Array[QTIChainLink] = []
    var cursor := 0
    var join_type := &"start"
    for m in matches:
        links.append(QTIChainLink.new(raw_input.substr(cursor, m["pos"] - cursor), join_type, cursor))
        cursor = m["end"]
        join_type = _JOIN_TYPES[m["op"]]
    links.append(QTIChainLink.new(raw_input.substr(cursor), join_type, cursor))
    return links

func tokenize(segment: String) -> Array[QTIToken]:
    return QTITokenizerUtil.tokenize_quoted(segment, {"single_quote_literal": true})

func bind_arguments(tokens: Array[QTIToken], def: QTICommandDef, full_segment: String) -> QTIBindResult:
    var all_by_name := {}
    for a in def.positional_args:
        all_by_name[a.name.to_lower()] = a
    for f in def.flags:
        all_by_name[f.name.to_lower()] = f

    var bound := {}
    var leftover: Array[QTIToken] = []
    var i := 0
    var n := tokens.size()
    while i < n:
        var t: QTIToken = tokens[i]
        if t.text.begins_with("-") and t.text.length() > 1 and not _looks_like_negative_number(t.text):
            var param_name := t.text.substr(1)
            var matched: QTIArgument = all_by_name.get(param_name.to_lower())
            if matched == null:
                return QTIBindResult.failure("Unknown parameter: -%s" % param_name)
            if matched.is_flag:
                bound[matched.name] = true
                i += 1
                continue
            if i + 1 >= n:
                return QTIBindResult.failure("Missing value for parameter '-%s'." % param_name)
            var value_token: QTIToken = tokens[i + 1]
            if matched.rest:
                bound[matched.name] = QTITokenizerUtil.raw_remainder(full_segment, value_token.start)
                i = n
            else:
                bound[matched.name] = value_token.text
                i += 2
            continue
        leftover.append(t)
        i += 1

    var li := 0
    for arg_def in def.positional_args:
        if bound.has(arg_def.name):
            continue
        if li >= leftover.size():
            continue
        if arg_def.rest:
            bound[arg_def.name] = QTITokenizerUtil.raw_remainder(full_segment, leftover[li].start)
            li = leftover.size()
        else:
            bound[arg_def.name] = leftover[li].text
            li += 1

    if li < leftover.size():
        return QTIBindResult.failure("Too many arguments for '%s'. Usage: %s" % [def.name, def.usage_string()])

    return QTIBindResult.ok(bound)

func supports_piping() -> bool:
    return true

func resolve_pipe_input(previous_result: QTIResult, next_arg_defs: Array[QTIArgument]) -> Dictionary:
    return _default_resolve_pipe_input(previous_result, next_arg_defs)

func get_chain_operators() -> Dictionary:
    return {"sequence": ";", "pipe": "|"}

static func _looks_like_negative_number(text: String) -> bool:
    if text.length() < 2:
        return false
    var second := text[1]
    if second >= "0" and second <= "9":
        return true
    if second == "." and text.length() > 2 and text[2] >= "0" and text[2] <= "9":
        return true
    return false
