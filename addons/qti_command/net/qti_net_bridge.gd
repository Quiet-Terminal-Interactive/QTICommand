## Multiplayer bridge that routes [code]server_only()[/code] commands to the authoritative peer and drives result replication.
##
## Add an instance of this node to your scene tree and register it with [method QTICommand.attach_net_bridge]. The bridge uses Godot's built-in [MultiplayerAPI]; no ENet or WebSocket knowledge is required.
## [br][br]
## Security note: [code]server_only()[/code] forwards raw input via RPC and re-runs permission checks server-side. Validating that the claimed [code]sender_id[/code] is authorised for a particular invoker identity is the responsibility of your [QTIPermissionResolver] and [method set_sender_context_provider].
class_name QTINetBridge
extends Node

## The dispatcher used to re-execute commands received from remote peers. Set automatically by [method QTICommand.attach_net_bridge].
var dispatcher: QTIDispatcher = null
var _replication_handler: Callable = Callable()
var _sender_context_provider: Callable = Callable()

## Sets the callable invoked after a [code]replicate()[/code] command succeeds.
## Signature: [code](command_name: String, result: QTIResult) -> void[/code].
func set_replication_handler(callable: Callable) -> void:
    _replication_handler = callable

## Sets the callable that builds a [QTIContext] for an incoming remote dispatch.
## Signature: [code](sender_id: int) -> QTIContext[/code].
## When not set, a bare context is created with [code]metadata["sender_id"][/code] populated.
func set_sender_context_provider(callable: Callable) -> void:
    _sender_context_provider = callable

## Returns [code]true[/code] when a [MultiplayerPeer] is active.
func is_networked() -> bool:
    return multiplayer != null and multiplayer.has_multiplayer_peer()

## Returns [code]true[/code] when this peer is the network authority, or when there is no active multiplayer session.
func is_server() -> bool:
    if not is_networked():
        return true
    return multiplayer.is_server()

## Sends [param raw_input] to the server peer via RPC for authoritative dispatch. Called automatically for [code]server_only()[/code] commands on non-server peers.
func request_remote_dispatch(raw_input: String) -> void:
    rpc_id(1, "_qti_remote_dispatch", raw_input)

## Invokes the replication handler (if set) with the succeeded command result. Called automatically by [QTIDispatcher] for [code]replicate()[/code] commands.
func replicate(command_name: String, result: QTIResult) -> void:
    if _replication_handler.is_valid():
        _replication_handler.call(command_name, result)

@rpc("any_peer", "call_remote", "reliable")
func _qti_remote_dispatch(raw_input: String) -> void:
    if dispatcher == null:
        push_error("QTINetBridge: received a remote dispatch request but no dispatcher is attached.")
        return
    if not multiplayer.is_server():
        push_error("QTINetBridge: _qti_remote_dispatch invoked on a non-server peer; ignoring.")
        return

    var sender_id := multiplayer.get_remote_sender_id()
    var ctx: QTIContext
    if _sender_context_provider.is_valid():
        ctx = _sender_context_provider.call(sender_id)
    else:
        ctx = QTIContext.new()
        ctx.metadata["sender_id"] = sender_id
    ctx.source = &"network"

    dispatcher.dispatch(raw_input, ctx)
