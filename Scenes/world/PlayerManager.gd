extends Node2D
# TODO - Move this to the PlayerMultiplayerSpawner like Bullets have it
const PlayerScene := preload("res://Scenes/characters/players/Player.tscn")

var players := {}

func _ready():
    $PlayerMultiplayerSpawner.spawn_function = _spawn_player_custom
    
    if multiplayer.is_server():
        multiplayer.peer_connected.connect(_on_peer_connected)
        multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func _spawn_player_custom(data: Variant) -> Node:
    var peer_id = data as int
    print("Custom spawning player:", peer_id)
    
    var p = PlayerScene.instantiate()
    p.name = "Player_%d" % peer_id
    p.peer_id = peer_id
    p.position = Vector2.ZERO
    
    p.set_multiplayer_authority(peer_id)	
    p.get_node("MultiplayerSynchronizer").set_multiplayer_authority(1)
    
    players[peer_id] = p
    return p

func _on_peer_connected(id):
    print("Peer connected:", id)
    $PlayerMultiplayerSpawner.spawn(id)

func _on_peer_disconnected(id):
    print("Peer disconnected:", id)
    var p = players.get(id)
    if p:
        p.queue_free()
        players.erase(id)
