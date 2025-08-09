class_name Player3D
extends CharacterBody3D

@onready var animated_sprite = $AnimatedSprite3D
@onready var multiplayer_sync = $MultiplayerSynchronizer

@export var speed := 6
@export var max_health = 99
var current_health = 100
var input_vector := Vector3.ZERO
var aim_direction: Vector3 = Vector3.ZERO
var shooting := false
var fire_cooldown := 0.0
var peer_id := -1 # Gets set in PlayerSpawner
var is_submerged := false
var location: String = "%016x" % [randi()] # Which map we're in for syncing multiplayer stuff. Start with a random string to prevent lobby people syncing with eachother

var hud_scene = preload("res://Scenes/hud/hud.tscn")
var hud_instance: HUD

func _enter_tree() -> void:
    if get_multiplayer().is_server():
        $MultiplayerSynchronizer.add_visibility_filter(_visibility_filter)
        $MultiplayerSynchronizer.update_visibility()
        
func _visibility_filter(to_peer: int) -> bool:
    return PlayerManager.map_players.get(to_peer, false)

func _ready():
    if is_multiplayer_authority():
        _setup_camera()

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
    $Camera3D.make_current()


var last_input_direction = Vector3.ZERO
func _physics_process(delta):
    # Only server processes movement and shooting
    if not multiplayer.is_server():
        return

    velocity = Vector3(input_vector.x * speed, -100, input_vector.z * speed)

    # Direction and raycast update
    var dir := Vector3(input_vector.x, 0, input_vector.z)
    if dir.length() > 0.01:
        last_input_direction = dir.normalized()
    $HeadRayCast3D.target_position = Vector3(input_vector.x, 0, input_vector.z)
    $HeadRayCast3D.force_raycast_update()

    # Climb logic
    if is_on_floor() and is_on_wall() and not $HeadRayCast3D.is_colliding():
        global_translate(Vector3.UP * 1.1)
        
    floor_snap_length = 1.1
    apply_floor_snap() # Without this, running against a wall you can't climb up makes you go megaspastic
    move_and_slide()

    # Handle shooting
    fire_cooldown -= delta
    if shooting and fire_cooldown <= 0:
        var bulletspawner: BulletSpawner = get_tree().get_first_node_in_group("bullet_spawner")
        var bullet_pos = global_position
        bullet_pos.y = 2
        aim_direction.y = 0
        bulletspawner.spawn_bullet(BulletData.new("tier_0_bullet.png", bullet_pos, aim_direction, Yeet.MOB_LAYER))
        fire_cooldown = WeaponHelper.get_cooldown(peer_id)

func _process(delta):
    # Only the owning client handles input
    if not is_multiplayer_authority():
        return
        
    if hud_instance:
        hud_instance.update_health(current_health, max_health)

    var local_input = Vector3(
        Input.get_action_strength("right") - Input.get_action_strength("left"),
        0,
        Input.get_action_strength("down") - Input.get_action_strength("up")
    )

    # Rotate input around Y axis by camera's global Y rotation
    var angle = $Camera3D.global_transform.basis.get_euler().y
    input_vector = local_input.rotated(Vector3.UP, angle).normalized()

    # Aim direction: get the mouse position and calculate direction in world space
    var mouse_position = get_viewport().get_mouse_position()
    var mouse_ray_origin = $Camera3D.project_ray_origin(mouse_position)
    var mouse_ray_normal = $Camera3D.project_ray_normal(mouse_position)

    # Calculate the direction the player should aim towards
    # Get a point some distance along the mouse ray
    var target_point = mouse_ray_origin + mouse_ray_normal * 10
    target_point.y = global_position.y
    aim_direction = (target_point - global_position).normalized()

    var shoot = Input.is_action_pressed("shoot")

    # Handle animations
    if input_vector == Vector3.ZERO:
        animated_sprite.play("stand")
    else:
        animated_sprite.set_flip_h(Input.get_action_strength("left") > 0)
        animated_sprite.play("walk")

    # Send input to server
    receive_input.rpc_id(1, input_vector, aim_direction, shoot)

    # Rotate camera around y axis
    var camera_vector = Vector2(Input.get_action_strength("clockwise"), Input.get_action_strength("counter_clockwise")).normalized()
    $Camera3D.rotate_y((camera_vector.x - camera_vector.y) * delta * 1.5)

# TODO - Could I possibly replace this with MultiplayerSync?
@rpc("any_peer", "call_local", "unreliable")
func receive_input(move: Vector3, aim: Vector3, shoot: bool):
    # Only server processes input
    if not multiplayer.is_server():
        return

    input_vector = move
    aim_direction = aim
    shooting = shoot

func take_damage(damage: int):
    assert(multiplayer.is_server(), "Client is somehow calculating their own damage")
    current_health -= damage
