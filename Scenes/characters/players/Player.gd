class_name Player
extends CharacterBody2D

@onready var animated_sprite = $AnimatedSprite2D
@onready var water_detector = $WaterDetector
@export var speed := 200
@export var max_health = 99
var current_health = 100
var input_vector := Vector2.ZERO
var aim_direction := Vector2.ZERO
var shooting := false
var fire_cooldown := 0.0
var peer_id := 0
var is_submerged := false

func _ready():
    water_detector.setup(animated_sprite)
    water_detector.water_status_changed.connect(_on_water_status_changed)
    if is_multiplayer_authority():
        _setup_camera()
        self.z_index = RenderingServer.CANVAS_ITEM_Z_MAX
        
        $MultiplayerSynchronizer.synchronized.connect(_on_sync)
        
func _setup_camera():
    $Camera2D.make_current()

func _physics_process(delta):
    water_detector.check_water_status(global_position)
    
    # Only server processes movement and shooting
    if not multiplayer.is_server():
        return
    
    # Handle movement
    var speed_multiplier = 1
    if is_submerged:
        speed_multiplier *= 0.8
    velocity = input_vector * speed * speed_multiplier
    move_and_slide()
    
    # Handle shooting
    fire_cooldown -= delta
    if shooting and fire_cooldown <= 0:
        spawn_bullet()
        fire_cooldown = 0.25

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

    # Handle animations
    if input_vector == Vector2.ZERO:
        animated_sprite.stop()
    else:
        animated_sprite.set_flip_h(Input.get_action_strength("left") > 0)
        if input_vector.x == -1 or input_vector.x == 1:
            animated_sprite.play("horizontal_walk")
        if input_vector.y == -1:
            animated_sprite.play("upwards_walk")
        if input_vector.y == 1:
            animated_sprite.play("downwards_walk")

    # Send input to server
    receive_input.rpc_id(1, input_vector, aim_dir, shoot)

@rpc("any_peer", "call_local", "unreliable")
func receive_input(move: Vector2, aim: Vector2, shoot: bool):
    # Only server processes input
    if not multiplayer.is_server():
        return
    
    input_vector = move
    aim_direction = aim
    shooting = shoot

func spawn_bullet():
    var bullet_data = {
        "position": global_position,
        "direction": aim_direction,
        "damage": 50,  # Could vary based on weapon
        "speed": 400
    }
    get_tree().get_first_node_in_group("bullet_spawner").spawn_bullet("player_basic", bullet_data)

func _on_water_status_changed(in_water: bool):
    if not multiplayer.is_server():
        return
    
    # Prevent multiple applications
    if in_water == is_submerged:
        return
        
    is_submerged = in_water
    
    if in_water:
        global_position.y += 8
    else:
        global_position.y -= 8
    
    # Apply visual effect to all clients
    sync_water_state.rpc(in_water)

@rpc("any_peer", "call_local", "reliable")
func sync_water_state(in_water: bool):
    if water_detector and water_detector.shader_material:
        water_detector.shader_material.set_shader_parameter("in_water", in_water)

func take_damage(damage: int):
    assert(multiplayer.is_server(), "Client is somehow calculating their own damage")
    current_health -= damage

func _on_sync():
    if not is_multiplayer_authority():
        return
    var hud: HUD = get_tree().get_first_node_in_group("hud")
    hud.update_health(current_health, max_health)
