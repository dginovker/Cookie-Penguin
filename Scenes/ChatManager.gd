extends Node

@rpc("any_peer", "call_local", "unreliable_ordered", 999)
func send_chat_message(message: String):
    if not multiplayer.is_server():
        return
    var sender_id = multiplayer.get_remote_sender_id()
    var player_name = "Player%d" % sender_id
    
    # Broadcast to all clients
    receive_chat_message.rpc(player_name, message)

@rpc("any_peer", "call_local", "unreliable_ordered", 999)
func receive_chat_message(player_name: String, message: String):
    if multiplayer.is_server():
        # Just log it
        print("Chat: " + player_name + " - " + message)
    else:
        # Find HUD on client and display message
        var hud = get_tree().get_first_node_in_group("hud")
        hud.add_chat_message(player_name, message)
