# Top-down camera that shows ≥ minRadiusM in both axes on Y=0, but never more than needed.
extends Camera3D

@export var minRadiusM: float = 4.0
@export var baseFovDeg: float = 70.0  # vertical FOV

func _ready() -> void:
    assert(rotation_degrees.x == -90.0)
    fov = baseFovDeg
    get_viewport().size_changed.connect(update_camera_fit)
    update_camera_fit()

func update_camera_fit() -> void:
    var vp: Vector2i = get_viewport().size
    var aspect_ratio: float = float(vp.x) / float(vp.y)
    var limiting_axis_scale: float = min(1.0, aspect_ratio)  # portrait binds; landscape binds at 1
    var vertical_half_angle: float = deg_to_rad(fov) * 0.5
    var required_height: float = minRadiusM / (tan(vertical_half_angle) * limiting_axis_scale)
    global_position.y = required_height  # ground is Y=0; hardcoded
