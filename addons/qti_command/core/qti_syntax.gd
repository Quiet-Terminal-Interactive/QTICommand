## String constants for the built-in [QTISyntaxProvider]s.
##
## Pass these to [method QTICommand.set_syntax] / [method QTICommand.register_syntax]. Custom syntaxes registered via [method QTICommand.register_syntax] are identified by whatever string name you choose; these constants exist purely for readability and to avoid typo-prone literals.
class_name QTISyntax
extends RefCounted

const DEFAULT := "default"
const BASH := "bash"
const POWERSHELL := "powershell"
