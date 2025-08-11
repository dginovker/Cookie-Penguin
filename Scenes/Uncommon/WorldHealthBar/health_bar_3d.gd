extends Control
class_name HealthBar

@onready var fill_bar = $Fill
@export var y_offset_px: int = 24 # how many pixels above the world point

func update_health(percent_health: float):
    fill_bar.size.x = $Shell.size.x * percent_health

func update_location(world_position: Vector3):
    var cam = get_viewport().get_camera_3d()
    if not cam:
        return

    # Project to screen (viewport) coordinates
    var screen_pos: Vector2 = cam.unproject_position(world_position)

    # Optional: clamp to screen so it never leaves view
    var vp_size: Vector2 = get_viewport_rect().size
    screen_pos.x = clampf(screen_pos.x, 0.0, vp_size.x - size.x)
    screen_pos.y = clampf(screen_pos.y, 0.0, vp_size.y - size.y)

    # Nudge above the target and center horizontally over it
    screen_pos += Vector2(-size.x * 0.5, -y_offset_px)

    global_position = screen_pos
