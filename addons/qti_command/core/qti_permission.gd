## Base permission resolver that grants every invoker every role.
##
## Extend this class and override [method has_permission] to integrate with your game's role or privilege system, then install the subclass with [method QTICommand.set_permission_resolver].
class_name QTIPermissionResolver
extends RefCounted

## Returns [code]true[/code] if [param invoker] holds [param role]. The default implementation always returns [code]true[/code] (open access). Override this in a subclass to enforce your own permission rules.
func has_permission(invoker: Variant, role: String) -> bool:
    return true
