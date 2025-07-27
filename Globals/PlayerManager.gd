# Globally created
extends Node

var players: Dictionary[int, Player3D] = {}

func start_listening():
    multiplayer.peer_connected.connect(spawn_player)
    multiplayer.peer_disconnected.connect(despawn_player)

func spawn_player(id):
    assert(multiplayer.is_server())
    print("Peer connected:", id)
    var player_spawner: PlayerSpawner3D = get_tree().get_first_node_in_group("player_spawner")
    players[id] = player_spawner.spawn(id)
    print("Spawned them :)")
    if id != 1:
        load_scene_on_client.rpc_id(id)
        print("Called the RPC")


func despawn_player(id):
    assert(multiplayer.is_server())
    print("Peer disconnected:", id)
    var p = players.get(id)
    if p:
        p.queue_free()
        players.erase(id)


@rpc("authority", "call_remote", "reliable")
func load_scene_on_client():
    print("Got the RPC call")
    # The server calls this RPC when the client is ready to enter the scene
    assert(!multiplayer.is_server())
    print("The server has told us to load the scene!")
    var game_scene = load("res://Scenes/3dWorld/3Dworld.tscn").instantiate()
    get_tree().root.add_child(game_scene)
    queue_free()  # remove the main menu
    
