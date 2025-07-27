# BaseBullet.gd
extends Area3D
class_name BulletInstance

@export var lifetime := 10.0
@export var pierce_count := 0
@export var bullet: Bullet

var pierced_targets = 0
var shooter_type = ""

var _pending_global_position: Vector3
var _pending_collision_mask: int

# This gets called by MultiplayerSpawner
func initialize(p_bullet: Bullet):
    assert(p_bullet != null)
    bullet = p_bullet
    _pending_global_position = bullet.start_position
    _pending_collision_mask = bullet.collision_mask
    
func _enter_tree():
    global_position = _pending_global_position
    collision_mask = _pending_collision_mask
    
func _ready():
    if not multiplayer.is_server():
        return
    
    connect("body_entered", _on_body_entered)
    get_tree().create_timer(lifetime).timeout.connect(queue_free)

func _physics_process(delta):
    if not is_inside_tree():
        return
    position += bullet.direction * bullet.speed * delta

func _on_body_entered(body):
    if not multiplayer.is_server():
        return
    
    if body.is_in_group("walls"):
        hit_wall(body)
    else:
        hit_target(body)
    
func hit_target(target):
    assert(multiplayer.is_server(), "Client is somehow triggering hit_target")
    target.take_damage(bullet.damage)
    
    pierced_targets += 1
    if pierced_targets > pierce_count:
        queue_free()

func hit_wall(_wall):
    queue_free()
