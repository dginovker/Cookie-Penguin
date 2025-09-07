class_name Player3D
extends CharacterBody3D
"""
Main player
Player positions are bulk updated in a single RPC in NetSnapshotHub
Player spawning and despawning is not maintained by a syncronizer, it's done by hand in NetSnapshotHub
"""

@onready var animated_sprite = $AnimatedSprite3D as Sprite3DHelper
@onready var autofire_area = $AutofireArea3D
@onready var healthbar := $HealthBar
@onready var input := $Input as PlayerInput
@onready var cam := $Camera3D
@onready var rb := $RollbackSynchronizer as RollbackSynchronizer
@onready var ti := $TickInterpolator as TickInterpolator

var stats_rev = 0
@export var attack := 0
@export var speed := 3.5
@export var max_health := 100.0
@export var xp := 0
@export var health := 100

var input_vector := Vector3.ZERO
var peer_id := -1 # Gets set in PlayerSpawner

var fire_cooldown := 0.0
var mobs_in_range: Array[Node3D] = []

var hud_scene = preload("res://Scenes/hud/hud.tscn")
var hud_instance: HUD

@export var terrain: TerrainMask

func _enter_tree() -> void:
    add_to_group("players")

func _ready():
    if multiplayer.is_server():
        var sword := ItemInstance.new("tier_0_sword", ItemLocation.new(ItemLocation.Type.PLAYER_GEAR, peer_id, 0))
        ItemManager.spawn_item(sword)
        autofire_area.body_entered.connect(_autofire_area_entered)
        autofire_area.body_exited.connect(_autofire_area_exited)

    if peer_id == multiplayer.get_unique_id():
        _setup_camera()
        setup_hud()
        ItemManager.request_item_sync.rpc_id(1, peer_id) # Load our gear

    await get_tree().process_frame

    # --- Netfox nodes are created *now*, when we're fully in-tree ---
    rb.add_visibility_filter(func(to_peer:int): return PlayerManager.players.has(to_peer) && PlayerManager.players[to_peer].spawned_players.has(peer_id))

    # --- Ownership AFTER nodes exist, THEN tell Netfox authority changed ---
    set_multiplayer_authority(1)               # server owns state
    $Input.set_multiplayer_authority(peer_id)  # local player owns input
    rb.process_settings()

func setup_hud():
    var ui_layer: Control = get_tree().get_first_node_in_group("ui_root")
    hud_instance = hud_scene.instantiate()
    ui_layer.add_child(hud_instance)
    hud_instance.player = self

func _setup_camera():
    cam.make_current()

func _process(delta):
    healthbar.update_health(max(health, 0) / max_health)
    healthbar.update_location(global_position)

    animated_sprite.waste_cut = terrain.is_in(global_position, TerrainDefs.Type.SHALLOW, 1) or terrain.is_in(global_position, TerrainDefs.Type.LAVA, 1)

    # Only the player who uses this character handles input presentation + HUD
    if multiplayer.get_unique_id() != peer_id:
        return

    if hud_instance:
        hud_instance.update_health(health, max_health)
        hud_instance.update_xp(xp)

    # Handle animations from *intent* (not authoritative state)
    if input.movement == Vector3.ZERO:
        animated_sprite.play("stand")
    else:
        animated_sprite.set_flip_h(Input.get_action_strength("left") > 0)
        animated_sprite.play("walk")

    # Rotate camera around y axis (visual only)
    var cv := Vector2(Input.get_action_strength("clockwise"), Input.get_action_strength("counter_clockwise")).normalized()
    cam.rotate_y((cv.x - cv.y) * delta * 1.5)

# ---- Authoritative simulation (server + rollback) ----
func _rollback_tick(_delta, _tick, _is_fresh):
    # Movement: derive from absolute input every tick; no latching, no reuse
    velocity = input.movement.normalized() * speed
    velocity *= NetworkTime.physics_factor
    move_and_slide()
    velocity /= NetworkTime.physics_factor

func _physics_process(delta: float) -> void:
    if !multiplayer.is_server():
        return
    # Autofire logic (server authoritative)
    fire_cooldown -= delta
    if _get_nearest_mob() != null and fire_cooldown <= 0:
        var spawner: BulletSpawner = get_tree().get_first_node_in_group("bullet_spawner")
        var pos = global_position
        var aim: Vector3 = (_get_nearest_mob().global_position - global_position).normalized()
        aim.y = 0
        var bullet_name := WeaponHelper.get_bullet_name_for_player(peer_id)
        spawner.spawn_bullet(
            BulletData.new(
                attack + BulletData.get_bullet_damage(bullet_name),
                BulletData.get_bullet_speed(bullet_name),
                bullet_name,
                pos,
                aim,
                Yeet.MOB_LAYER
            )
        )
        fire_cooldown = WeaponHelper.get_cooldown_for_player(peer_id)

func level_up():
    assert(multiplayer.is_server())
    speed += 1
    attack += 1
    max_health += 5
    var net_director: NetDirector = get_tree().get_first_node_in_group("realm_net_director")
    net_director.stats.buffer_stat_update(self)

func take_damage(damage: int):
    LazyRPCs.pop_damage.rpc(get_path(), damage, max(health, 0) / max_health)
    assert(multiplayer.is_server(), "Client is somehow calculating their own damage")
    health -= damage
    var net_director: NetDirector = get_tree().get_first_node_in_group("realm_net_director")
    net_director.stats.buffer_stat_update(self)

func _autofire_area_entered(body: Node3D) -> void:
    if not body.is_in_group("mobs"):
        return
    mobs_in_range.append(body)

func _autofire_area_exited(body: Node3D) -> void:
    if not body.is_in_group("mobs"):
        return
    mobs_in_range.erase(body)

func _get_nearest_mob() -> Node3D:
    mobs_in_range = mobs_in_range.filter(func(p: Node3D): return is_instance_valid(p) and p.is_visible)
    if mobs_in_range.is_empty():
        return null
    var nearest = mobs_in_range[0]
    var nd = global_position.distance_squared_to(nearest.global_position)
    for m in mobs_in_range:
        var d = global_position.distance_squared_to(m.global_position)
        if d < nd:
            nearest = m
            nd = d
    return nearest
