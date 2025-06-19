class_name Player
extends CharacterBody2D

@onready var animated_sprite = $AnimatedSprite2D
@onready var water_detector = $WaterDetector
@export var speed := 200
@export var max_health = 99
var current_health = 100
var input_vector := Vector2.ZERO
var aim_direction: Vector2 = Vector2.ZERO
var shooting := false
var fire_cooldown := 0.0
var peer_id := -1 # Gets set in PlayerSpawner
var is_submerged := false

var hud_scene = preload("res://Scenes/hud/hud.tscn")
var hud_instance

func _ready():
    water_detector.setup(animated_sprite)
    water_detector.water_status_changed.connect(_on_water_status_changed)
    if is_multiplayer_authority():
        _setup_camera()
        self.z_index = RenderingServer.CANVAS_ITEM_Z_MAX
        $MultiplayerSynchronizer.synchronized.connect(_on_sync)
        
        # Defer HUD creation to next frame
        call_deferred("setup_hud")

func setup_hud():
    var ui_layer = get_viewport().get_node_or_null("UILayer")
    if not ui_layer:
        ui_layer = CanvasLayer.new()
        ui_layer.name = "UILayer"
        ui_layer.layer = 10
        get_viewport().add_child(ui_layer)
    
    hud_instance = hud_scene.instantiate()
    ui_layer.add_child(hud_instance)
    hud_instance.update_health(current_health, max_health)
     
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
        var bulletspawner: BulletSpawner = get_tree().get_first_node_in_group("bullet_spawner")
        bulletspawner.spawn_bullet(BulletType.new("tier_0_bullet.png", global_position, aim_direction, 2**2 + 1))
        fire_cooldown = WeaponHelper.get_cooldown(peer_id)

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
    if hud_instance:
        hud_instance.update_health(current_health, max_health)
