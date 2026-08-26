## The outcome of [method QTISyntaxProvider.bind_arguments].
##
## [member bound] maps argument/flag name to its raw value: [String] for positional/rest arguments, [bool] or [String] for flags. Type-parsing against the command's declared [QTIArgument]s still happens afterward in [QTIDispatcher]; this only carries raw values.
class_name QTIBindResult
extends RefCounted

## [code]true[/code] if binding succeeded (this does not mean type-parsing will also succeed).
var success: bool = false
## arg_name -> raw value, as described above. Only meaningful when [member success] is [code]true[/code].
var bound: Dictionary = {}
## Human-readable failure reason. Only meaningful when [member success] is [code]false[/code].
var error_message: String = ""

static func ok(bound: Dictionary) -> QTIBindResult:
    var r := QTIBindResult.new()
    r.success = true
    r.bound = bound
    return r

static func failure(msg: String) -> QTIBindResult:
    var r := QTIBindResult.new()
    r.success = false
    r.error_message = msg
    return r
