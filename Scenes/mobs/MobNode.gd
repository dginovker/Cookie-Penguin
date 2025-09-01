class_name MobNode
extends CharacterBody3D
# Spawn is managed by MobMultiplayerSpawner
# Todo - add interpolation

var mob_id: int = -1

@export var speed = 2.0
@export var shoot_cooldown = 1.0
@export var wander_range = 100.0
@export var health: float = 100.0
@export var max_health: float = -1.0
@export var xp_given: int = 5
@export var drop_table: Dictionary[String, float] = {
    "health_potion": 1,
    "tier_0_sword": 0.5
}
@export var bullet_name = 'tier_0_bullet.png'

var mob_kind: String
var players_in_range: Array[Player3D] = [] # Players we shoot and give xp to on death
var wander_direction = Vector3.ZERO
var wander_timer = 0.0
var shoot_timer = 0.0
var wander_center: Vector3
var is_paused = false
var pause_timer = 0.0

@onready var aggro_area: Area3D = $AggressionArea
@onready var healthbar := $HealthBar

func _ready():
    # Server has authority over all mobs
    set_multiplayer_authority(1)  # 1 = server ID

    max_health = health

    # Only server runs mob logic
    if not is_multiplayer_authority():
        return

    wander_center = global_position
    _new_wander_direction()
    aggro_area.body_entered.connect(_on_player_entered)
    aggro_area.body_exited.connect(_on_player_exited)

func _process(_delta):
    healthbar.update_health(max(health, 0) / max_health)
    healthbar.update_location(global_position)

func _physics_process(delta):
    # Only server processes mob AI and movement
    if not is_multiplayer_authority():
        return

    shoot_timer -= delta
    pause_timer -= delta

    var target_player: Player3D = _get_nearest_player()
    if target_player:
        wander_center = global_position
        _chase_player(target_player, delta)
    else:
        _wander(delta)

    move_and_slide()

func _chase_player(player: Player3D, _delta):
    var direction: Vector3 = (player.global_position - global_position).normalized()
    direction.y = 0
    velocity = direction * speed

    if shoot_timer <= 0:
        shoot_at_player(player)
        shoot_timer = shoot_cooldown

func shoot_at_player(player):
    var to_player = player.global_position - global_position
    to_player.y = 0
    var bullet_direction = to_player.normalized()
    var bullet_pos = global_position
    var bullet_type: BulletData = BulletData.new(
            BulletData.get_bullet_damage(bullet_name),
            BulletData.get_bullet_speed(bullet_name),
            bullet_name,
            bullet_pos,
            bullet_direction,
            Yeet.PLAYER_LAYER
        )
    get_tree().get_first_node_in_group("bullet_spawner").spawn_bullet(bullet_type)

func _wander(delta):
    wander_timer -= delta

    if is_paused:
        velocity = Vector3.ZERO
        if pause_timer <= 0:
            is_paused = false
            _new_wander_direction()
        return

    if wander_timer <= 0 or global_position.distance_to(wander_center) > wander_range:
        _new_wander_direction()

    assert(wander_direction.y == 0)
    velocity = wander_direction * speed * 0.5

func _new_wander_direction():
    # Chance to pause instead of moving
    if randf() < 0.7:
        is_paused = true
        pause_timer = randf_range(1.0, 2.5)
        return

    # Choose direction that stays within wander range
    var attempts = 0
    while attempts < 10:
        wander_direction = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
        var test_position = global_position + wander_direction * speed * 0.5 * 2.0
        if test_position.distance_to(wander_center) <= wander_range:
            break
        attempts += 1

    wander_timer = randf_range(1.0, 3.0)

func _get_nearest_player():
    # Clean up invalid players first
    players_in_range = players_in_range.filter(func(p): return is_instance_valid(p))

    if players_in_range.is_empty():
        return null

    var nearest = players_in_range[0]
    var nearest_distance = global_position.distance_squared_to(nearest.global_position)

    for player in players_in_range:
        var distance = global_position.distance_squared_to(player.global_position)
        if distance < nearest_distance:
            nearest = player
            nearest_distance = distance

    return nearest

func _on_player_entered(body: Node3D):
    if body.is_in_group("players") and not players_in_range.has(body):
        players_in_range.append(body)

func _on_player_exited(body: Node3D):
    if body.is_in_group("players"):
        players_in_range.erase(body)

func take_damage(amount):
    assert(multiplayer.is_server(), "Client is somehow deciding how much damage mobs take")
    if health < 0:
        return

    LazyRPCs.pop_damage.rpc(get_path(), amount, max(health, 0) / max_health) # show on all peers

    health -= amount
    if health < 0:
        _die()

func _die() -> void:
    assert(multiplayer.is_server())
    var loot_spawner: LootSpawner = get_tree().get_first_node_in_group("loot_spawners")
    loot_spawner.spawn_from_drop_table(global_position, drop_table)

    for player: Player3D in players_in_range:
        if LevelsMath.get_level(player.xp) < LevelsMath.get_level(player.xp + xp_given):
            LazyRPCs.pop_level.rpc(player.get_path())
            player.level_up()
        else:
            # Looks ugly to give both xp and level up message at the same timeasd
            LazyRPCs.pop_xp.rpc(player.get_path(), xp_given)
        player.xp += xp_given
    queue_free()
