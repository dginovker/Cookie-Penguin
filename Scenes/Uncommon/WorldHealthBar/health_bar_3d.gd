extends Control
class_name HealthBar

@export var yOffsetPx: int = 30
@onready var bar: TextureProgressBar = $"." # root is the bar

var target: Node3D

func bind_target(t: Node3D) -> void:
    target = t
    target.tree_exiting.connect(_on_target_exiting)
    visible = false

func set_health01(x: float) -> void:
    # x in [0,1]
    visible = x < 1.0
    bar.value = bar.max_value * x

func _process(_dt: float) -> void:
    assert(target != null)
    var cam: Camera3D = get_viewport().get_camera_3d()
    assert(cam != null)
    set_health01(float(max(target.health, 0)) / float(target.max_health))
    var sp: Vector2 = cam.unproject_position(target.global_position)
    sp += Vector2(-size.x * 0.5, yOffsetPx)
    global_position = sp

func _on_target_exiting() -> void:
    queue_free()
