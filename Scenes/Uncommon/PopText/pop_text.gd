extends Label

var world_pos: Vector3
var offset_y := 0  # pixels

func pop_damage(world_pos_p: Vector3, text_p: String, hp_frac: float) -> void:
    world_pos = world_pos_p
    text = text_p
    modulate = Color(1.0 - hp_frac, hp_frac, 0.0)
    var t := create_tween()
    t.tween_property(self, "offset_y", -50.0, 2.0).set_ease(Tween.EASE_OUT)
    t.parallel().tween_property(self, "modulate:a", 0.0, 1.0).finished.connect(queue_free)

func pop_xp(world_pos_p: Vector3, text_p: String) -> void:
    world_pos = world_pos_p
    text = text_p
    modulate = Color.GREEN
    var t := create_tween()
    t.tween_property(self, "offset_y", -50.0, 2.0).set_ease(Tween.EASE_OUT).finished.connect(queue_free)

func _process(_dt):
    var cam := get_viewport().get_camera_3d()
    position = cam.unproject_position(world_pos) + Vector2(0, offset_y - 80)
