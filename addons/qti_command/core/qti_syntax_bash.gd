## Bash-flavored [QTISyntaxProvider]: [code]&&[/code]/[code]||[/code]/[code];[/code] chaining, [code]|[/code] piping, [code]$var[/code] substitution against [member QTIContext.metadata], and POSIX-ish quoting (double quotes with [code]\"[/code] escape, plus literal single-quote spans).
class_name QTISyntaxBash
extends QTISyntaxProvider

const _OPERATORS: Array[String] = ["&&", "||", ";", "|"]
const _JOIN_TYPES := {
    "&&": &"and",
    "||": &"or",
    ";": &"sequence",
    "|": &"pipe",
}

func get_name() -> String:
    return QTISyntax.BASH

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
    return QTISyntaxDefault.bind_positional_and_flags(tokens, def, full_segment)

func supports_piping() -> bool:
    return true

func resolve_pipe_input(previous_result: QTIResult, next_arg_defs: Array[QTIArgument]) -> Dictionary:
    return _default_resolve_pipe_input(previous_result, next_arg_defs)

func get_chain_operators() -> Dictionary:
    return {"and": "&&", "or": "||", "sequence": ";", "pipe": "|"}
