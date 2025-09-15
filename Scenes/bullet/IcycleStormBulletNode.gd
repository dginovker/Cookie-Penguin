extends Area3D
class_name IcycleStormBulletNode

const DAMAGE := 5
const SPEED := 12
const BULLET_NAME := "icycle_storm_bullet.png"
const ROTATION_RADIUS := 1.0
const DELAY_TIME := 1.0
const FIRING_DELAY := 0.1
const ROTATION_SPEED := -2 # Counter-clockwise

@onready var sprite := $Sprite
var storm_data: IcycleStormSpecAttackBulletData
var current_angle: float
var rotation_timer: float
var is_targeting: bool = false
var lifetime := 10.0
var direction: Vector3
var targeting_start_position: Vector3
var start_position: Vector3

func initialize(p_storm_data: IcycleStormSpecAttackBulletData):
    storm_data = p_storm_data
    current_angle = (storm_data.bullet_index * 2.0 * PI) / 8.0
    rotation_timer = 0.0
    collision_mask = Yeet.MOB_LAYER

func _enter_tree():
    collision_mask = Yeet.MOB_LAYER
    
func _ready():
    start_position = global_position
    sprite.texture = load("res://Scenes/bullet/" + BULLET_NAME)
    Yeet.billboard_me($Sprite)

    if not multiplayer.is_server():
        return
    
    connect("body_entered", _on_body_entered)

func _on_body_entered(body: Node3D):
    if not multiplayer.is_server():
        return
    
    if body.is_in_group("walls"):
        queue_free()
    else:
        body.take_damage(DAMAGE)
        queue_free()

func _physics_process(delta):
    if not is_inside_tree():
        return

    rotation_timer += delta
    
    var bullet_delay_time: float = DELAY_TIME + (storm_data.bullet_index * FIRING_DELAY)

    if rotation_timer < bullet_delay_time:
        _handle_rotation_phase(delta)
    else:
        if not is_targeting:
            _start_targeting_phase()
        _handle_targeting_phase(delta)

func _handle_rotation_phase(delta: float):
    var player: Player3D = PlayerManager.players.get(storm_data.player_id, {}).get("player")
    if not player or not is_instance_valid(player):
        queue_free()
        return

    current_angle += ROTATION_SPEED * delta
    var offset := Vector3(cos(current_angle), 0, sin(current_angle)) * ROTATION_RADIUS
    global_position = player.global_position + offset

func _start_targeting_phase():
    is_targeting = true
    targeting_start_position = global_position
    var nearest_enemy := _find_nearest_enemy()
    if nearest_enemy:
        direction = (nearest_enemy.global_position - global_position).normalized()
        direction.y = 0
    else:
        direction = Vector3(cos(current_angle), 0, sin(current_angle)).normalized()
    
    look_at(global_position + direction)

func _handle_targeting_phase(delta: float):
    position += direction * SPEED * delta
    if multiplayer.is_server() and position.distance_to(targeting_start_position) > lifetime:
        queue_free()

func _find_nearest_enemy() -> Node3D:
    var all_mobs: Array[Node] = get_tree().get_nodes_in_group("mobs")
    
    var nearest: Node3D = null
    var nearest_distance := INF

    for mob in all_mobs:
        if not is_instance_valid(mob) or not mob.is_visible:
            continue
        var distance := global_position.distance_squared_to(mob.global_position)
        if distance < nearest_distance:
            nearest = mob as Node3D
            nearest_distance = distance

    return nearest
