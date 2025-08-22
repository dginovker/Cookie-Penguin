# Globally created
extends Node

var players: Dictionary[int, Player3D] = {}
var map_players: Dictionary[int, bool] = {}

func start_listening():
    multiplayer.peer_connected.connect(spawn_player)
    multiplayer.peer_disconnected.connect(despawn_player)

func spawn_player(id):
    assert(multiplayer.is_server())
    print("Peer connected:", id)
    if id != 1:
        load_scene_on_client.rpc_id(id)
        print("Called the RPC")
    else:
        # Spawn the server player
        _spawn_player_for_real(1)

func despawn_player(id):
    assert(multiplayer.is_server())
    print("Peer disconnected:", id)
    players.erase(id)


@rpc("authority", "call_remote", "reliable")
func load_scene_on_client():
    print("Got the RPC call to load the scene")
    assert(!multiplayer.is_server())
    var game_scene = load("res://Scenes/3dWorld/3Dworld.tscn").instantiate()
    get_tree().root.add_child(game_scene)
    await get_tree().process_frame
    get_node("/root/ServerSelect").queue_free()  # remove the main menu
    print("Telling the server we loaded...")
    client_loaded_scene.rpc_id(1)

@rpc("any_peer", "call_remote", "reliable")
func client_loaded_scene():
    assert(multiplayer.is_server())
    var id := multiplayer.get_remote_sender_id()
    print("Client ", id, " says they loaded the scene, giving them visibilty of our syncronizers...")
    map_players[id] = true
    await get_tree().process_frame
    for mob in get_tree().get_nodes_in_group("mobs"):
        var sync = mob.get_node("MultiplayerSynchronizer")
        sync.update_visibility()
    _spawn_player_for_real(id)

func _spawn_player_for_real(id: int):
    var player_spawner: PlayerSpawner3D = get_tree().get_first_node_in_group("player_spawner")
    players[id] = player_spawner.spawn(id)
    players[id].global_position = Vector3(238, 0.01, 198)
