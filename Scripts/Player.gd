extends CharacterBody2D

@export var speed := 200
var input_vector := Vector2.ZERO
var peer_id := 0  # The owning peer
var aim_direction := Vector2.ZERO

func _physics_process(delta):
	if multiplayer.is_server():
		velocity = input_vector * speed
		move_and_slide()
  		
		# Broadcast updated state to clients
		sync_state(global_position, aim_direction)

func _process(delta):
	if multiplayer.get_unique_id() != peer_id:
		return  # not our player — skip input

	var input_vector = Vector2(
		Input.get_action_strength("right") - Input.get_action_strength("left"),
		Input.get_action_strength("down") - Input.get_action_strength("up")
	).normalized()

	var aim_dir = (get_global_mouse_position() - global_position).normalized()
	var shoot = Input.is_action_pressed("shoot")

	rpc_id(1, "receive_input", peer_id, input_vector, aim_dir, shoot)

@rpc("unreliable")
func sync_state(pos: Vector2, aim: Vector2):
	if multiplayer.get_unique_id() == peer_id:
		return  # Skip syncing self
	global_position = global_position.lerp(pos, 0.2)
	aim_direction = aim
