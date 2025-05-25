extends Node2D

const PlayerScene := preload("res://Scenes/Player.tscn")
const BulletScene = preload("res://Scenes/Bullet.tscn")
@onready var player_root := $players

var players := {}

func _ready():
	if multiplayer.is_server():
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)

		# Spawn any already-connected peers (e.g., if latejoin)
		for id in multiplayer.get_peers():
			_spawn_player(id)


func _physics_process(delta):
	if not multiplayer.is_server():
		return
	for peer_id in players.keys():
		var p = players[peer_id]
		p.fire_cooldown -= delta
		if not p.shooting:
			continue
		if p.fire_cooldown <= 0:
			_spawn_bullet(p.global_position, p.aim_direction)
			p.fire_cooldown = 0.25  # 4 bullets/sec

func _spawn_bullet(origin: Vector2, direction: Vector2):
	var bullet = BulletScene.instantiate()
	bullet.position = origin
	bullet.direction = direction.normalized()
	add_child(bullet)

	# Tell clients to show it
	rpc("rpc_spawn_bullet", origin, bullet.direction)
	
@rpc("any_peer", "call_local")
func rpc_spawn_bullet(pos: Vector2, direction: Vector2):
	if multiplayer.is_server():
		return  # server already has the bullet

	var bullet = BulletScene.instantiate()
	bullet.position = pos
	bullet.direction = direction.normalized()
	add_child(bullet)

func _on_peer_connected(id):
	print("Peer connected:", id)
	_spawn_player(id)

func _on_peer_disconnected(id):
	print("Peer disconnected:", id)
	var p = players.get(id)
	if p:
		p.queue_free()
		players.erase(id)

func _spawn_player(peer_id: int):
	print("Spawning player:", peer_id)
	var p = PlayerScene.instantiate()
	p.name = "Player_%d" % peer_id
	p.peer_id = peer_id
	p.position = Vector2.ZERO
	player_root.add_child(p)

	# This line makes ownership clear — server owns the node, but gives control to client
	p.set_multiplayer_authority(peer_id)

	players[peer_id] = p

	# Notify that the player was spawned
	rpc("rpc_spawn_player", peer_id, p.position)
	print("Called rpc_spawn_player:", peer_id)

@rpc("any_peer", "call_local")
func rpc_spawn_player(peer_id: int, pos: Vector2):
	print("rpc_spawn_player called for peer_id ", peer_id)
	if multiplayer.is_server():
		return  # server already did this locally
	var p = PlayerScene.instantiate()
	p.name = "Player_%d" % peer_id
	p.position = pos
	p.peer_id = peer_id
	player_root.add_child(p)
	
@rpc("any_peer")
func receive_input(peer_id: int, move: Vector2, aim: Vector2, shoot: bool):
	if not multiplayer.is_server():
		return

	var player = players.get(peer_id)
	if not player:
		return

	player.input_vector = move
	player.aim_direction = aim
	player.shooting = shoot
