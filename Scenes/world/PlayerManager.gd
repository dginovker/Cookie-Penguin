extends Node2D

var players: Dictionary[int, Player] = {}

func start_server():
    multiplayer.peer_connected.connect(_on_peer_connected)
    multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func _on_peer_connected(id):
    assert(multiplayer.is_server())
    print("Peer connected:", id)
    var player_spawner: PlayerSpawner = get_tree().get_first_node_in_group("player_spawner")
    players[id] = player_spawner.spawn(id)

func _on_peer_disconnected(id):
    assert(multiplayer.is_server())
    print("Peer disconnected:", id)
    var p = players.get(id)
    if p:
        p.queue_free()
        players.erase(id)
