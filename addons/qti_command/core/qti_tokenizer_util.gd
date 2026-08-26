## Shared quote/escape-aware scanning primitives used by every [QTISyntaxProvider].
class_name QTITokenizerUtil
extends RefCounted

static func tokenize_quoted(input: String, opts: Dictionary = {}) -> Array[QTIToken]:
    var single_quote_literal: bool = opts.get("single_quote_literal", false)
    var tokens: Array[QTIToken] = []
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
        elif single_quote_literal and input[i] == "'":
            i += 1
            while i < n and input[i] != "'":
                buf += input[i]
                i += 1
            if i < n:
                i += 1
        else:
            while i < n and input[i] != " ":
                buf += input[i]
                i += 1
        tokens.append(QTIToken.new(buf, start, i))
    return tokens

static func extract_flags(tokens: Array[QTIToken]) -> Dictionary:
    var positional: Array[QTIToken] = []
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

static func raw_remainder(input: String, from_char_index: int) -> String:
    if from_char_index >= input.length():
        return ""
    return input.substr(from_char_index).strip_edges()

static func is_inside_quotes(input: String, position: int, opts: Dictionary = {}) -> bool:
    return _quote_state_up_to(input, position, opts.get("single_quote_literal", false)) != ""

static func _quote_state_up_to(input: String, up_to: int, single_quote_literal: bool) -> String:
    var state := ""
    var i := 0
    var n := mini(up_to, input.length())
    while i < n:
        var c := input[i]
        if state == "double":
            if c == "\\" and i + 1 < n and input[i + 1] == "\"":
                i += 2
                continue
            if c == "\"":
                state = ""
            i += 1
            continue
        if state == "single":
            if c == "'":
                state = ""
            i += 1
            continue
        if c == "\"":
            state = "double"
            i += 1
            continue
        if single_quote_literal and c == "'":
            state = "single"
            i += 1
            continue
        i += 1
    return state

static func split_on_quote_aware(input: String, operators: Array[String], opts: Dictionary = {}) -> Array[Dictionary]:
    var single_quote_literal: bool = opts.get("single_quote_literal", false)
    var sorted_ops := operators.duplicate()
    sorted_ops.sort_custom(func(a, b): return a.length() > b.length())
    var matches: Array[Dictionary] = []
    var state := ""
    var i := 0
    var n := input.length()
    while i < n:
        var c := input[i]
        if state == "double":
            if c == "\\" and i + 1 < n and input[i + 1] == "\"":
                i += 2
                continue
            if c == "\"":
                state = ""
            i += 1
            continue
        if state == "single":
            if c == "'":
                state = ""
            i += 1
            continue
        if c == "\"":
            state = "double"
            i += 1
            continue
        if single_quote_literal and c == "'":
            state = "single"
            i += 1
            continue
        var matched_op := ""
        for op in sorted_ops:
            if op.length() > 0 and input.substr(i, op.length()) == op:
                matched_op = op
                break
        if matched_op != "":
            matches.append({"op": matched_op, "pos": i, "end": i + matched_op.length()})
            i += matched_op.length()
            continue
        i += 1
    return matches

static func substitute_variables(text: String, ctx: QTIContext, opts: Dictionary = {}) -> String:
    var single_quote_literal: bool = opts.get("single_quote_literal", false)
    var out := ""
    var state := ""
    var i := 0
    var n := text.length()
    while i < n:
        var c := text[i]
        if state == "single":
            if c == "'":
                state = ""
            out += c
            i += 1
            continue
        if state == "double" and c == "\\" and i + 1 < n and text[i + 1] == "\"":
            out += "\\\""
            i += 2
            continue
        if state == "double" and c == "\"":
            state = ""
            out += c
            i += 1
            continue
        if state == "" and c == "\"":
            state = "double"
            out += c
            i += 1
            continue
        if state == "" and single_quote_literal and c == "'":
            state = "single"
            out += c
            i += 1
            continue
        if c == "\\" and i + 1 < n and text[i + 1] == "$":
            out += "$"
            i += 2
            continue
        if c == "$":
            var j := i + 1
            var name := ""
            if j < n and text[j] == "{":
                j += 1
                var name_start := j
                while j < n and text[j] != "}":
                    j += 1
                name = text.substr(name_start, j - name_start)
                if j < n:
                    j += 1
            else:
                var name_start2 := j
                while j < n and _is_var_name_char(text[j]):
                    j += 1
                name = text.substr(name_start2, j - name_start2)
            if name == "":
                out += c
                i += 1
                continue
            if ctx != null and ctx.metadata.has(name):
                out += str(ctx.metadata[name])
            else:
                push_warning("QTICommand: syntax variable '$%s' is not set in ctx.metadata; substituting empty string." % name)
            i = j
            continue
        out += c
        i += 1
    return out

static func _is_var_name_char(ch: String) -> bool:
    if ch.length() != 1:
        return false
    var code := ch.unicode_at(0)
    return (code >= 48 and code <= 57) or (code >= 65 and code <= 90) or (code >= 97 and code <= 122) or code == 95
