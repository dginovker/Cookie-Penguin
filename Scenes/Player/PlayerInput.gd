extends Node
class_name PlayerInput
# Gathers absolute, per-tick input for rollback. No edge events; no latching.

var movement := Vector3.ZERO
@onready var cam := $"../Camera3D"

var _buf := Vector3.ZERO
var _samples := 0

func _ready():
    NetworkTime.before_tick_loop.connect(_gather)

func _process(_dt):
    var v2 := Input.get_vector("left", "right", "up", "down")
    var local := Vector3(v2.x, 0.0, v2.y)
    var angle = cam.global_transform.basis.get_euler().y
    _buf += local.rotated(Vector3.UP, angle)
    _samples += 1

func _gather():
    movement = _buf / _samples if _samples > 0 else Vector3.ZERO
    _buf = Vector3.ZERO
    _samples = 0
