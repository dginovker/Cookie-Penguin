extends Node2D

const PlayerScene := preload("res://Scenes/Player.tscn")
@onready var player_root := $players

var players := {}

func _ready():
	if multiplayer.is_server():
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)

		# Spawn player for the server (ID 1)
		_spawn_player(1)

		# Also spawn any already-connected peers (e.g., if latejoin)
		for id in multiplayer.get_peers():
			_spawn_player(id)

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
	var p = PlayerScene.instantiate()
	p.name = "Player_%d" % peer_id
	p.peer_id = peer_id
	p.position = Vector2(100 + peer_id * 64, 100)  # Example spacing
	player_root.add_child(p)

	# This line makes ownership clear — server owns the node, but gives control to client
	p.set_multiplayer_authority(peer_id)

	players[peer_id] = p

	# Notify that the player was spawned
	rpc("rpc_spawn_player", peer_id, p.position)

@rpc("any_peer", "call_local")
func rpc_spawn_player(peer_id: int, pos: Vector2):
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
