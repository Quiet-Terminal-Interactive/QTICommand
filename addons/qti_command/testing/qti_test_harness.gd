## Utilities for unit-testing commands without a running scene.
##
## Use [method mock] to construct a pre-configured [QTIContext] and pass it to [method QTICommand.simulate] or [method QTICommand.dispatch] in your tests.
class_name QTITestContext
extends RefCounted

## Minimal invoker stub used when no custom invoker is provided to [method mock].
class MockInvoker:
    ## Display name of this mock invoker (used in error messages and history keys).
    var name: String = "test_invoker"
    ## Numeric ID for the mock invoker (e.g. simulating a peer ID).
    var id: int = 0

## Creates a [QTIContext] suitable for test dispatch.
## [param overrides] may contain:
## [br]- [code]"invoker"[/code] ([Variant]) — custom invoker; defaults to a [MockInvoker].
## [br]- [code]"source"[/code] ([StringName]) — dispatch origin tag; defaults to [code]&"test"[/code].
## [br]- [code]"metadata"[/code] ([Dictionary]) — additional request-scoped data.
## [br]- [code]"syntax"[/code] ([Variant]) — a [QTISyntax] constant (or custom registered name); defaults to [constant QTISyntax.DEFAULT], unconditionally, so tests stay isolated from whatever [method QTICommand.set_syntax] a real game has configured globally.
## [br]- [code]"syntax_options"[/code] ([Dictionary]) — provider options paired with [code]"syntax"[/code] (e.g. [code]{"allow_sequence_chaining": true}[/code]).
static func mock(overrides: Dictionary = {}) -> QTIContext:
    var ctx := QTIContext.new()
    ctx.invoker = overrides.get("invoker", MockInvoker.new())
    ctx.source = overrides.get("source", &"test")
    ctx.metadata = overrides.get("metadata", {})
    ctx.syntax_override = overrides.get("syntax", QTISyntax.DEFAULT)
    ctx.syntax_override_options = overrides.get("syntax_options", {})
    return ctx
