# HealthBar.gd — stable screen-space offset using camera-up scale (no theme, no drift)

extends Control
class_name HealthBar

@export var offset_m: float = 0.45          # how far *below* the target in meters (screen-space mapped)
@export var center_x: bool = true

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

    # project once at the target depth
    var sp0: Vector2 = cam.unproject_position(target.global_position)

    # measure pixels-per-meter *at the target* along the camera's up axis
    var sp1: Vector2 = cam.unproject_position(target.global_position + cam.global_basis.y)
    var ppm: float = (sp1 - sp0).length()     # pixels per +1m along cam-up

    # apply the offset purely in screen-Y to avoid sideways drift
    var sp: Vector2 = sp0 + Vector2(0.0, ppm * offset_m)
    if center_x:
        sp.x -= size.x * 0.5

    global_position = sp

func _on_target_exiting() -> void:
    queue_free()
