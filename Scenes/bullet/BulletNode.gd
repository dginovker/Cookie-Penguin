extends Area3D
class_name BulletNode

@export var lifetime := 10.0
@export var pierce_count := 0

@onready var sprite = $Sprite

var bullet_data: BulletData

var pierced_targets = 0
var shooter_type = ""

var _pending_global_position: Vector3
var _pending_collision_mask: int

# This gets called by MultiplayerSpawner
func initialize(p_bullet_data: BulletData):
    assert(p_bullet_data != null)
    bullet_data = p_bullet_data
    _pending_global_position = bullet_data.start_position
    _pending_collision_mask = bullet_data.collision_mask
    
func _enter_tree():
    global_position = _pending_global_position
    collision_mask = _pending_collision_mask
    
func _ready():
    sprite.texture = load("res://Scenes/bullet/" + bullet_data.bullet_name)
    if not multiplayer.is_server():
        return
    
    connect("body_entered", _on_body_entered)
    get_tree().create_timer(lifetime).timeout.connect(queue_free)

func _physics_process(delta):
    if not is_inside_tree():
        return
    position += bullet_data.direction * bullet_data.speed * delta

func _on_body_entered(body: Node3D):
    if not multiplayer.is_server():
        return
    
    if body.is_in_group("walls"):
        hit_wall(body)
    else:
        hit_target(body)
    
func hit_target(target: Node3D):
    assert(multiplayer.is_server(), "Client is somehow triggering hit_target")
    target.take_damage(bullet_data.damage)
    
    pierced_targets += 1
    if pierced_targets > pierce_count:
        queue_free()

func hit_wall(_wall):
    queue_free()
