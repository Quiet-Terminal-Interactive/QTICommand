## Demonstrates pluggable command syntax: switching the global grammar, overriding it per invocation source, and registering a fully custom QTISyntaxProvider. See docs/SYNTAX.md for the full reference.
extends Node

func _ready() -> void:
    # Global default: bash-style chaining/piping/$var substitution everywhere.
    QTICommand.set_syntax(QTISyntax.BASH)

    # Per-source override: a trusted admin console can use PowerShell-style named parameters even while the global default (or a different per-source override for chat) stays elsewhere.
    QTICommand.set_syntax(QTISyntax.POWERSHELL, {"source": &"console"})

    # A fully custom provider is registered the same way custom argument types are.
    QTICommand.register_syntax("fish", ExampleFishSyntax.new())
    # QTICommand.set_syntax("fish")

    _demo()

func _demo() -> void:
    QTICommand.register("list_players") \
        .description("Lists connected players") \
        .execute(func(ctx: QTIContext) -> QTIResult:
            return ctx.ok("alice, bob", {"pipe_list": ["alice", "bob"]})
    )
    QTICommand.register("greet") \
        .description("Greets a name") \
        .arg("name", QTIType.STRING, {"rest": true}) \
        .execute(func(ctx: QTIContext) -> QTIResult:
            return ctx.ok("Hello, %s!" % ctx.arg("name"))
    )

    var ctx := QTIContext.new()
    ctx.source = &"test"
    ctx.metadata = {"greeting_target": "world"}

    # Chaining + $var substitution under BASH syntax.
    print(QTICommand.dispatch("/greet $greeting_target", ctx).message) # "Hello, world!"

    # Piping list_players' pipe_list into greet's rest argument.
    print(QTICommand.dispatch("/list_players | greet", ctx).message) # "Hello, alice\nbob!"

## Minimal illustrative custom syntax: identical to QTISyntax.DEFAULT except it also recognizes a fish-style ";" sequence separator unconditionally (no opt-in flag). A real custom provider would usually extend QTISyntaxProvider directly rather than delegating to the built-in DEFAULT provider, but doing so here keeps this example short.
class ExampleFishSyntax:
    extends QTISyntaxProvider

    func get_name() -> String:
        return "fish"

    func split_chain(raw_input: String) -> Array[QTIChainLink]:
        return QTISyntaxDefault.new().with_options({"allow_sequence_chaining": true}).split_chain(raw_input)

    func tokenize(segment: String) -> Array[QTIToken]:
        return QTITokenizerUtil.tokenize_quoted(segment)

    func bind_arguments(tokens: Array[QTIToken], def: QTICommandDef, full_segment: String) -> QTIBindResult:
        return QTISyntaxDefault.bind_positional_and_flags(tokens, def, full_segment)
