# players node in the World scene
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
    
    # They control the player, we control the syncronizer
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

func _physics_process(delta):
    if not multiplayer.is_server():
        return
        
    # Handle shooting for all players
    for peer_id in players.keys():
        var p = players[peer_id]
        if not is_instance_valid(p):
            continue
        p.fire_cooldown -= delta
        if p.shooting and p.fire_cooldown <= 0:
            var bullet_data = {
                "position": p.global_position,
                "direction": p.aim_direction
            }
            $BulletMultiplayerSpawner.spawn(bullet_data)
            p.fire_cooldown = 0.25

@rpc("authority", "call_local", "reliable")
func _spawn_bullet(origin: Vector2, direction: Vector2):
    var bullet = BulletScene.instantiate()
    bullet.position = origin
    bullet.direction = direction.normalized()
    add_child(bullet)

func _on_peer_connected(id):
    print("Peer connected:", id)
    $PlayerMultiplayerSpawner.spawn(id)

func _on_peer_disconnected(id):
    print("Peer disconnected:", id)
    var p = players.get(id)
    if p:
        p.queue_free()
        players.erase(id)

@rpc("any_peer", "call_local", "reliable")
func receive_input(peer_id: int, move: Vector2, aim: Vector2, shoot: bool):
    if not multiplayer.is_server():
        return

    var player = players.get(peer_id)
    if not player:
        return

    player.input_vector = move
    player.aim_direction = aim
    player.shooting = shoot
