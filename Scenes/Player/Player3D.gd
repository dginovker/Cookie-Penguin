class_name Player3D
extends CharacterBody3D

@onready var animated_sprite = $AnimatedSprite3D as Sprite3DHelper
@onready var multiplayer_sync = $MultiplayerSynchronizer
@onready var autofire_area = $AutofireArea3D
@onready var healthbar := $HealthBar

@export var attack := 0
@export var speed := 3.5
@export var max_health := 100.0
@export var xp := 0
@export var health = 100.0

var input_vector := Vector3.ZERO

var peer_id := -1 # Gets set in PlayerSpawner
var location: String = "%016x" % [randi()] # Which map we're in for syncing multiplayer stuff. Start with a random string to prevent lobby people syncing with eachother

var fire_cooldown := 0.0
var mobs_in_range: Array[Node3D] = []

var hud_scene = preload("res://Scenes/hud/hud.tscn")
var hud_instance: HUD

@export var terrain: TerrainMask

func _enter_tree() -> void:
    if get_multiplayer().is_server():
        $MultiplayerSynchronizer.add_visibility_filter(_visibility_filter)
        $MultiplayerSynchronizer.update_visibility()

func _visibility_filter(to_peer: int) -> bool:
    return PlayerManager.map_players.get(to_peer, false)

func _ready():
    if multiplayer.is_server():
        # Give new players a sword to start
        var sword := ItemInstance.new("tier_0_sword", ItemLocation.new(ItemLocation.Type.PLAYER_GEAR, peer_id, 0))
        ItemManager.spawn_item(sword)

        autofire_area.body_entered.connect(_autofire_area_entered)
        autofire_area.body_exited.connect(_autofire_area_exited)

    if is_multiplayer_authority():
        _setup_camera()

        setup_hud()
        ItemManager.request_item_sync.rpc_id(1, peer_id) # Load our gear

func setup_hud():
    var ui_layer = get_viewport().get_node_or_null("UILayer")
    if not ui_layer:
        ui_layer = CanvasLayer.new()
        ui_layer.name = "UILayer"
        ui_layer.layer = 10
        get_viewport().add_child(ui_layer)

    hud_instance = hud_scene.instantiate()
    ui_layer.add_child(hud_instance)
    hud_instance.update_health(health, max_health)
    hud_instance.player = self

func _setup_camera():
    $Camera3D.make_current()

var last_input_direction = Vector3.ZERO
func _physics_process(delta):
    # Only server processes movement and shooting
    if not multiplayer.is_server():
        return

    velocity = Vector3(input_vector.x * speed, 0, input_vector.z * speed)
    move_and_slide()

    # Handle shooting
    fire_cooldown -= delta
    if _get_nearest_mob() != null and fire_cooldown <= 0:
        var bulletspawner: BulletSpawner = get_tree().get_first_node_in_group("bullet_spawner")
        var bullet_pos = global_position
        bullet_pos.y = 2
        var aim_direction: Vector3 = (_get_nearest_mob().global_position - global_position).normalized()
        aim_direction.y = 0
        var bullet_name := WeaponHelper.get_bullet_name(peer_id)
        bulletspawner.spawn_bullet(
            BulletData.new(
                attack + BulletData.get_bullet_damage(bullet_name),
                BulletData.get_bullet_speed(bullet_name),
                bullet_name,
                bullet_pos,
                aim_direction,
                Yeet.MOB_LAYER
            )
        )
        fire_cooldown = WeaponHelper.get_cooldown(peer_id)

func _process(delta):
    healthbar.update_health(max(health, 0) / max_health)
    healthbar.update_location(global_position)

    animated_sprite.waste_cut = terrain.is_in(global_position, TerrainDefs.Type.SHALLOW, 1) or terrain.is_in(global_position, TerrainDefs.Type.LAVA, 1)

    # Only the owning client handles input and hud stuff
    if not is_multiplayer_authority():
        return

    if hud_instance:
        hud_instance.update_health(health, max_health)
        hud_instance.update_xp(xp)

    var v2 := Input.get_vector("left", "right", "up", "down")
    var local_input := Vector3(v2.x, 0.0, v2.y)

    # Rotate input around Y axis by camera's global Y rotation
    var angle = $Camera3D.global_transform.basis.get_euler().y
    input_vector = local_input.rotated(Vector3.UP, angle)

    # Handle animations
    if input_vector == Vector3.ZERO:
        animated_sprite.play("stand")
    else:
        animated_sprite.set_flip_h(Input.get_action_strength("left") > 0)
        animated_sprite.play("walk")

    # Send input to server
    receive_input.rpc_id(1, input_vector)

    # Rotate camera around y axis
    var camera_vector = Vector2(Input.get_action_strength("clockwise"), Input.get_action_strength("counter_clockwise")).normalized()
    $Camera3D.rotate_y((camera_vector.x - camera_vector.y) * delta * 1.5)

func level_up():
    assert(is_multiplayer_authority())
    speed += 1
    attack += 1
    max_health += 5

@rpc("any_peer", "call_local", "unreliable")
func receive_input(move: Vector3):
    # Only server processes input
    if not multiplayer.is_server():
        return

    input_vector = move

func take_damage(damage: int):
    LazyRPCs.pop_damage.rpc(get_path(), damage, max(health, 0) / max_health)
    assert(multiplayer.is_server(), "Client is somehow calculating their own damage")
    health -= damage

func _autofire_area_entered(body: Node3D) -> void:
    if not body.is_in_group("mobs"):
        return
    mobs_in_range.append(body)

func _autofire_area_exited(body: Node3D) -> void:
    if not body.is_in_group("mobs"):
        return
    mobs_in_range.erase(body)

func _get_nearest_mob() -> Node3D:
    # Clean up invalid mobs first
    mobs_in_range = mobs_in_range.filter(func(p: Node3D): return is_instance_valid(p) and p.is_visible)

    if mobs_in_range.is_empty():
        return null

    var nearest = mobs_in_range[0]
    var nearest_distance = global_position.distance_squared_to(nearest.global_position)

    for mob in mobs_in_range:
        var distance = global_position.distance_squared_to(mob.global_position)
        if distance < nearest_distance:
            nearest = mob
            nearest_distance = distance

    return nearest
