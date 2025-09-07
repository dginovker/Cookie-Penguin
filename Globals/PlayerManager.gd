# PlayerManager.gd - Autoload
extends Node

class PlayerState:
    var player: Player3D = null
    var in_map: bool = false # Whether the player is in the Map yet
    var spawned_players: Dictionary[int, bool] = {} # The other players we already told this client to spawn
    var spawned_mobs: Dictionary[int, bool] = {} # The mobs we told this client to spawn
    
var players: Dictionary[int, PlayerState] = {}
const player_scene = preload("res://Scenes/Player/Player3D.tscn")

func start_listening():
    multiplayer.peer_connected.connect(spawn_player)
    multiplayer.peer_disconnected.connect(despawn_player)

func spawn_player(id):
    assert(multiplayer.is_server())
    print("Peer connected:", id)
    if id != 1:
        load_scene_on_client.rpc_id(id)
        print("Called the RPC to tell client ", id, " to load the scene")
    else:
        # Spawn the server player
        _spawn_player_for_real(1)

func despawn_player(id):
    assert(multiplayer.is_server())
    print("Peer disconnected:", id)
    if not players.has(id):
        # We never even spawned them
        return
    players[id].player.queue_free()
    players.erase(id) # SpawnReplicator will handle despawning for clients


@rpc("authority", "call_remote", "reliable")
func load_scene_on_client():
    assert(!multiplayer.is_server())
    print("Got the RPC call to load the scene")
    var game_scene = load("res://Scenes/3dWorld/3Dworld.tscn").instantiate()
    get_tree().root.add_child(game_scene)
    get_tree().root.get_node("RootRoot/ServerConnection").queue_free()  # remove the main menu
    client_loaded_scene.rpc_id(1)

@rpc("any_peer", "call_remote", "reliable")
func client_loaded_scene():
    assert(multiplayer.is_server())
    var id := multiplayer.get_remote_sender_id()
    _spawn_player_for_real(id)

func _spawn_player_for_real(id: int):
    # Runs on both server and client
    assert(get_tree().get_first_node_in_group("player_holder") != null)
    players[id] = PlayerState.new()
    players[id].player = player_scene.instantiate()
    players[id].player.name = "Player_%d" % id
    players[id].player.peer_id = id
    get_tree().get_first_node_in_group("player_holder").add_child(players[id].player)
    players[id].player.global_position = Vector3(238, 0.1, 198)
    players[id].in_map = true
