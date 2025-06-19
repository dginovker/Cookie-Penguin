# BaseBullet.gd
extends Area2D
class_name BulletInstance

@export var lifetime := 10.0
@export var pierce_count := 0
@export var bullet_type: BulletType

var pierced_targets = 0
var shooter_type = ""

# This gets called by MultiplayerSpawner
func initialize(p_bullet_type: BulletType):
    assert(p_bullet_type != null)
    bullet_type = p_bullet_type
    global_position = bullet_type.start_position
    collision_mask = bullet_type.collision_mask
    
func _ready():
    if not multiplayer.is_server():
        return
    
    connect("body_entered", _on_body_entered)
    get_tree().create_timer(lifetime).timeout.connect(queue_free)

func _process(delta):
    if not is_inside_tree():
        return
    position += bullet_type.direction * bullet_type.speed * delta

func _on_body_entered(body):
    if not multiplayer.is_server():
        return
    
    if body.is_in_group("walls"):
        hit_wall(body)
    else:
        hit_target(body)
    
func hit_target(target):
    assert(multiplayer.is_server(), "Client is somehow triggering hit_target")
    target.take_damage(bullet_type.damage)
    
    pierced_targets += 1
    if pierced_targets > pierce_count:
        queue_free()

func hit_wall(_wall):
    queue_free()
