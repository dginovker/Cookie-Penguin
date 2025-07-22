extends Node2D

var players: Dictionary[int, Player] = {}

func start_listening():
    multiplayer.peer_connected.connect(spawn_player)
    multiplayer.peer_disconnected.connect(despawn_player)

func spawn_player(id):
    assert(multiplayer.is_server())
    print("Peer connected:", id)
    var player_spawner: PlayerSpawner = get_tree().get_first_node_in_group("player_spawner")
    players[id] = player_spawner.spawn(id)

func despawn_player(id):
    assert(multiplayer.is_server())
    print("Peer disconnected:", id)
    var p = players.get(id)
    if p:
        p.queue_free()
        players.erase(id)
