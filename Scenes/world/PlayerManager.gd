extends Node2D

const PlayerScene := preload("res://Scenes/characters/players/Player.tscn")
const BulletScene = preload("res://Scenes/bullet/bullet.tscn")

var players := {}

func _ready():
    $PlayerMultiplayerSpawner.spawn_function = _spawn_player_custom
    $BulletMultiplayerSpawner.spawn_function = _spawn_bullet_custom
    
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

func _spawn_bullet_custom(data: Variant) -> Node:
    var bullet_data = data as Dictionary
    var bullet = BulletScene.instantiate()
    bullet.position = bullet_data["position"]
    bullet.direction = bullet_data["direction"]
    return bullet

func _on_peer_connected(id):
    print("Peer connected:", id)
    $PlayerMultiplayerSpawner.spawn(id)

func _on_peer_disconnected(id):
    print("Peer disconnected:", id)
    var p = players.get(id)
    if p:
        p.queue_free()
        players.erase(id)
