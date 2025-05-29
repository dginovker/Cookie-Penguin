extends CharacterBody2D

@onready var animated_sprite = $AnimatedSprite2D
@export var speed := 200
var input_vector := Vector2.ZERO
var aim_direction := Vector2.ZERO
var shooting := false
var fire_cooldown := 0.0
var peer_id := 0

func _enter_tree():
	# Authority is already set by the custom spawn function
	# Just make camera current if this is our player
	if is_multiplayer_authority():
		# Defer to ensure camera exists
		call_deferred("_setup_camera")

func _setup_camera():
	if has_node("Camera2D"):
		$Camera2D.make_current()

func _physics_process(_delta):
	# Only the server processes movement
	if not multiplayer.is_server():
		return
		
	velocity = input_vector * speed
	move_and_slide()

func _process(_delta):
	# Only the owning client handles input
	if not is_multiplayer_authority():
		return

	input_vector = Vector2(
		Input.get_action_strength("right") - Input.get_action_strength("left"),
		Input.get_action_strength("down") - Input.get_action_strength("up")
	).normalized()

	var aim_dir = (get_global_mouse_position() - global_position).normalized()
	var shoot = Input.is_action_pressed("shoot")
	
	if input_vector == Vector2.ZERO:
		animated_sprite.stop()
	else:
		animated_sprite.play("walk")
		animated_sprite.set_flip_h(Input.get_action_strength("left") > 0)
	
	get_parent().rpc_id(1, "receive_input", peer_id, input_vector, aim_dir, shoot)
