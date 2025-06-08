# BaseBullet.gd
extends Area2D
class_name BaseBullet

@export var speed := 270
@export var damage := 25
@export var lifetime := 10.0
@export var pierce_count := 0

var direction = Vector2.ZERO
var pierced_targets = 0
var shooter_type = ""

# This gets called by MultiplayerSpawner with the spawn data
func initialize(spawn_data: Dictionary):
    global_position = spawn_data.position
    direction = spawn_data.direction
    
    # Apply any additional properties
    for property in spawn_data:
        if property in self:
            set(property, spawn_data[property])

func _ready():
    if not multiplayer.is_server():
        return
    
    connect("body_entered", _on_body_entered)
    get_tree().create_timer(lifetime).timeout.connect(queue_free)

func _process(delta):
    if not is_inside_tree():
        return
    position += direction * speed * delta

func _on_body_entered(body):
    if not multiplayer.is_server():
        return
    
    if body.is_in_group("walls"):
        hit_wall(body)
    # We don't need to check if it hit a player vs a mob
    # since bullets have the collision mask set to only
    # collide with non-friendly targets
    hit_target(body)
    
func hit_target(target):
    if target.has_method("take_damage"):
        target.take_damage(damage)
    
    pierced_targets += 1
    if pierced_targets > pierce_count:
        queue_free()

func hit_wall(_wall):
    queue_free()
