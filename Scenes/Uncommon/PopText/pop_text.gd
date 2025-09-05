class_name PopText
extends Label

var target: Node3D
var _last_known_position: Vector3
var offset_y := 0  # pixels

func pop_damage(target_p: Node3D, text_p: String, hp_frac: float) -> void:
    target = target_p
    text = text_p
    modulate = Color(1.0 - hp_frac, hp_frac, 0.0)
    var t := create_tween()
    t.tween_property(self, "offset_y", -50.0, 2.0).set_ease(Tween.EASE_OUT)
    t.parallel().tween_property(self, "modulate:a", 0.0, 1.0).finished.connect(queue_free)

func pop_xp(target_p: Node3D, text_p: String) -> void:
    target = target_p
    text = text_p
    modulate = Color.GREEN
    z_index = 500
    var t := create_tween()
    t.tween_property(self, "offset_y", -50.0, 2.0).set_ease(Tween.EASE_OUT).finished.connect(queue_free)

func pop_levelup(target_p: Node3D) -> void:
    target = target_p
    text = "LEVEL UP"
    modulate = Color.GREEN
    z_index = 1000
    var t := create_tween()
    t.tween_property(self, "offset_y", -50.0, 2.0).set_ease(Tween.EASE_OUT).finished.connect(queue_free)

func _process(_dt: float) -> void:
    var cam := get_viewport().get_camera_3d()
    if target and target.is_inside_tree():
        _last_known_position = target.global_position
    if not _last_known_position:
        queue_free()
        return
    position = cam.unproject_position(_last_known_position) + Vector2(-size.x * 0.5, offset_y - 80)
