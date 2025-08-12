# DamagePopup3D.gd
extends Label3D

func pop(world_pos: Vector3, amount: int, percent_left: float) -> void:
    text = "-" + str(amount)
    global_position = world_pos + Vector3.UP * 1.6
    modulate = Color(1.0 - percent_left, percent_left, 0.0) # green→red
    var t = create_tween()
    t.tween_property(self, "position:y", position.y + 0.8, 0.6)
    await t.finished
    queue_free()
