## Splits a command body string into typed tokens using the default (non-pluggable) grammar.
##
## Handles quoted strings (with [code]\"[/code] escape) and separates [code]--flag[/code] tokens from positional arguments.
class_name QTITokenizer
extends RefCounted

## Splits [param input] on whitespace and returns an ordered array of [QTIToken]s. Quoted substrings (e.g. [code]"hello world"[/code]) are treated as one token and the surrounding quotes are stripped. Use [code]\"[/code] to embed a literal quote inside a quoted string.
static func tokenize(input: String) -> Array[QTIToken]:
    return QTITokenizerUtil.tokenize_quoted(input)

## Separates flag tokens ([code]--name[/code] or [code]--name=value[/code]) from positional tokens and returns a [Dictionary] with keys:
## [br]- [code]"positional"[/code] ([Array][QTIToken]) — non-flag tokens in order.
## [br]- [code]"flags"[/code] ([Dictionary]) — flag name → value ([code]true[/code]
##   for bare flags, string for [code]--name=value[/code] form).
static func extract_flags(tokens: Array[QTIToken]) -> Dictionary:
    return QTITokenizerUtil.extract_flags(tokens)

## Returns the unstripped substring of [param input] starting at character index [param from_char_index], with leading and trailing whitespace removed. Used to capture [code]rest[/code]-type arguments as a raw string.
static func raw_remainder(input: String, from_char_index: int) -> String:
    return QTITokenizerUtil.raw_remainder(input, from_char_index)
