extends CharacterBody2D

@export var speed := 200
var input_vector := Vector2.ZERO
var aim_direction := Vector2.ZERO
var shooting := false
var fire_cooldown := 0.0
var peer_id := 0

func _physics_process(_delta):
	if not multiplayer.is_server():
		return
	velocity = input_vector * speed
	move_and_slide()

	# Broadcast updated state to clients
	rpc("sync_state", global_position, aim_direction)

func _process(_delta):
	if multiplayer.get_unique_id() != peer_id:
		return  # not our player — skip input

	input_vector = Vector2(
		Input.get_action_strength("right") - Input.get_action_strength("left"),
		Input.get_action_strength("down") - Input.get_action_strength("up")
	).normalized()

	var aim_dir = (get_global_mouse_position() - global_position).normalized()
	var shoot = Input.is_action_pressed("shoot")

	var game = get_tree().root.get_node("Game")
	game.rpc_id(1, "receive_input", peer_id, input_vector, aim_dir, shoot)

func _ready():
	if multiplayer.get_unique_id() == peer_id:
		$Camera2D.make_current()

@rpc("reliable")
func sync_state(pos: Vector2, aim: Vector2):
	global_position = global_position.lerp(pos, 0.2)
	aim_direction = aim
	global_position = pos
