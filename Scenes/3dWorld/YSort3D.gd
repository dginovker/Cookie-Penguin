extends Node3D

# This code basically makes any sprite that is lower down on the screen
# render ABOVE any sprite that visually appears higher on the screen

@export var sprite: SpriteBase3D

func _process(_delta):
    var camera = get_viewport().get_camera_3d()
    if camera == null:
        return

    # Convert world position to screen position
    var screen_pos = camera.unproject_position(global_transform.origin)
    # Usually I could just set render_priority to screen_pos.y, but the render server doesn't have that large range..
    
    var screen_height = get_viewport().size.y
    var y_normalized = clamp(screen_pos.y / screen_height, 0.0, 1.0)
    var priority = int(lerp(RenderingServer.MATERIAL_RENDER_PRIORITY_MIN, RenderingServer.MATERIAL_RENDER_PRIORITY_MAX, y_normalized))
    sprite.render_priority = priority
