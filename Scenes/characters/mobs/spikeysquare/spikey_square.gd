extends CharacterBody2D

# Spawn is managed by MobMultiplayerSpawner

@export var speed = 50.0
@export var shoot_cooldown = 1.0
@export var wander_range = 100.0
@export var debug = true
@export var health = 100

# Simplified loot system - just list item names and chances
@export var loot_drop_chance = 0.7  # 70% chance to drop loot
@export var loot_items: Array[String] = ["health_potion"]  # Items that can drop
@export var drop_chances: Array[float] = [0.8]  # Chance for each item

@onready var hit_particles = $HitGPUParticles2D
@onready var death_particles = $DeathGPUParticles2D

var players_in_range = []
var wander_direction = Vector2.ZERO
var wander_timer = 0.0
var shoot_timer = 0.0
var wander_center: Vector2
var is_paused = false
var pause_timer = 0.0

func _ready():
    set_multiplayer_authority(1)
    
    if not is_multiplayer_authority():
        return
        
    wander_center = global_position
    _new_wander_direction()
    $AggressionArea.body_entered.connect(_on_player_entered)
    $AggressionArea.body_exited.connect(_on_player_exited)

func _physics_process(delta):
    if not is_multiplayer_authority():
        return
        
    shoot_timer -= delta
    pause_timer -= delta
    
    var target_player = _get_nearest_player()
    if target_player:
        wander_center = global_position
        _chase_player(target_player, delta)
    else:
        _wander(delta)
    
    move_and_slide()

func _draw():
    if not debug or not is_multiplayer_authority():
        return

    var aggro_shape = $AggressionArea/CollisionShape2D.shape
    var size = aggro_shape.size
    draw_rect(Rect2(-size/2, size), Color.RED, false, 2.0)

    var target = _get_nearest_player()
    if target:
        var to_player = target.global_position - global_position
        draw_line(Vector2.ZERO, to_player, Color.YELLOW, 3.0)

func _chase_player(player, _delta):
    var direction = (player.global_position - global_position).normalized()
    velocity = direction * speed
    
    if shoot_timer <= 0:
        shoot_at_player(player)
        shoot_timer = shoot_cooldown
    
    if debug:
        queue_redraw()
        
func shoot_at_player(player):
    var bullet_direction = (player.global_position - global_position).normalized()
    var bullet_data = {
        "position": global_position,
        "direction": bullet_direction,
        "damage": 25,
        "speed": 200
    }
    
    get_tree().get_first_node_in_group("bullet_spawner").spawn_bullet("enemy_basic", bullet_data)
    
func _wander(delta):
    wander_timer -= delta
    
    if is_paused:
        velocity = Vector2.ZERO
        if pause_timer <= 0:
            is_paused = false
            _new_wander_direction()
        return
    
    if wander_timer <= 0 or is_on_wall() or global_position.distance_to(wander_center) > wander_range:
        _new_wander_direction()
    
    velocity = wander_direction * speed * 0.5
    
    if debug:
        queue_redraw()

func _new_wander_direction():
    if randf() < 0.7:
        is_paused = true
        pause_timer = randf_range(1.0, 2.5)
        return
    
    var attempts = 0
    while attempts < 10:
        wander_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
        var test_position = global_position + wander_direction * speed * 0.5 * 2.0
        if test_position.distance_to(wander_center) <= wander_range:
            break
        attempts += 1
    
    wander_timer = randf_range(1.0, 3.0)

func _get_nearest_player():
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

func _on_player_entered(body):
    if body.is_in_group("players") and not players_in_range.has(body):
        players_in_range.append(body)

func _on_player_exited(body):
    if body.is_in_group("players"):
        players_in_range.erase(body)

func take_damage(amount):
    assert(multiplayer.is_server(), "Client is somehow deciding how much damage mobs take")
    if health < 0:
        return

    show_damage_effect.rpc()
    
    if not multiplayer.is_server():
        return
    
    health -= amount
    if health < 0:
        handle_death.rpc()

@rpc("any_peer", "call_local", "reliable")
func show_damage_effect():
    hit_particles.restart()

@rpc("any_peer", "call_local", "reliable") 
func handle_death():
    set_physics_process(false)
    set_process(false)
    $CollisionShape2D.set_deferred("disabled", true)
    $Sprite2D.visible = false
    
    death_particles.restart()
    
    if multiplayer.is_server():
        call_deferred("roll_loot_drops")
        await get_tree().create_timer(death_particles.lifetime).timeout
        queue_free()

func roll_loot_drops():
    if not multiplayer.is_server():
        return
    
    # Check if we should drop anything
    if randf() > loot_drop_chance:
        return
    
    # Roll for each possible item
    var dropped_items = []
    for i in range(loot_items.size()):
        var item_name: String = loot_items[i]
        var chance: float = drop_chances[i]
        
        if randf() <= chance:
            # Create item using ItemRegistry data
            var item_data = ItemRegistry.get_item_data(item_name)
            dropped_items.append({
                "id": generate_unique_id(),
                "item_name": item_name,
                # Copy all properties from ItemRegistry
                "type": item_data.type,
                "rarity": item_data.rarity,
                "stats": item_data.stats
            })
    
    # Spawn loot bag if we have items
    if not dropped_items.is_empty():
        var loot_spawner: LootSpawner = get_tree().get_first_node_in_group("loot_spawners")
        var spawn_data = {
            "position": global_position,
            "items": dropped_items
        }
        loot_spawner.spawn_loot_bag(spawn_data)

func generate_unique_id() -> String:
    return str(Time.get_unix_time_from_system()) + "_" + str(randi())
