## Splits a command body string into typed tokens.
##
## Handles quoted strings (with [code]\"[/code] escape) and separates [code]--flag[/code] tokens from positional arguments. Used internally by [QTIDispatcher]; not needed in normal command authoring.
class_name QTITokenizer
extends RefCounted

## A single parsed token with its text and character-position span.
class Token:
    ## The unquoted token text.
    var text: String
    ## Character index of the first character in the original input.
    var start: int
    ## Character index one past the last character in the original input.
    var end: int

    func _init(p_text: String, p_start: int, p_end: int) -> void:
        text = p_text
        start = p_start
        end = p_end

## Splits [param input] on whitespace and returns an ordered array of [Token]s. Quoted substrings (e.g. [code]"hello world"[/code]) are treated as one token and the surrounding quotes are stripped. Use [code]\"[/code] to embed a literal quote inside a quoted string.
static func tokenize(input: String) -> Array[Token]:
    var tokens: Array[Token] = []
    var i := 0
    var n := input.length()
    while i < n:
        while i < n and input[i] == " ":
            i += 1
        if i >= n:
            break
        var start := i
        var buf := ""
        if input[i] == "\"":
            i += 1
            while i < n:
                var c := input[i]
                if c == "\\" and i + 1 < n and input[i + 1] == "\"":
                    buf += "\""
                    i += 2
                    continue
                if c == "\"":
                    i += 1
                    break
                buf += c
                i += 1
        else:
            while i < n and input[i] != " ":
                buf += input[i]
                i += 1
        tokens.append(Token.new(buf, start, i))
    return tokens

## Separates flag tokens ([code]--name[/code] or [code]--name=value[/code]) from positional tokens and returns a [Dictionary] with keys:
## [br]- [code]"positional"[/code] ([Array][Token]) — non-flag tokens in order.
## [br]- [code]"flags"[/code] ([Dictionary]) — flag name → value ([code]true[/code]
##   for bare flags, string for [code]--name=value[/code] form).
static func extract_flags(tokens: Array[Token]) -> Dictionary:
    var positional: Array[Token] = []
    var flags: Dictionary = {}
    for t in tokens:
        if t.text.begins_with("--") and t.text.length() > 2:
            var body := t.text.substr(2)
            var eq := body.find("=")
            if eq != -1:
                flags[body.substr(0, eq)] = body.substr(eq + 1)
            else:
                flags[body] = true
        else:
            positional.append(t)
    return {"positional": positional, "flags": flags}

## Returns the unstripped substring of [param input] starting at character index [param from_char_index], with leading and trailing whitespace removed. Used to capture [code]rest[/code]-type arguments as a raw string.
static func raw_remainder(input: String, from_char_index: int) -> String:
    if from_char_index >= input.length():
        return ""
    return input.substr(from_char_index).strip_edges()
