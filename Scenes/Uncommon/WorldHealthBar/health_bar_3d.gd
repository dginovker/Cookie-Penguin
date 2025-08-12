extends Control
class_name HealthBar

@onready var bar: TextureProgressBar = $"."
@export var y_offset_px: int = 30

func _enter_tree() -> void:
    visible = false # prevent flicker in top left every time a mob spawns

func update_health(percent_health: float):
    visible = percent_health < 1
    bar.value = bar.max_value * percent_health

func update_location(world_position: Vector3):
    var cam = get_viewport().get_camera_3d()
    if not cam:
        return

    # Project to screen (viewport) coordinates
    var screen_pos: Vector2 = cam.unproject_position(world_position)

    screen_pos += Vector2(-size.x * 0.5, y_offset_px)

    global_position = screen_pos
