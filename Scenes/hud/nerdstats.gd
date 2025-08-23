extends Control

@export var seconds := 60.0
@export var fps_max := 200.0
@export var ping_max := 400.0

var times := PackedFloat32Array()
var fps := Array()
var ping_ms := Array()
var t := 0.0

func set_data(_times, _fps, _ping, _t):
    times = _times; fps = _fps; ping_ms = _ping; t = _t
    queue_redraw()

func _draw() -> void:
    if fps.size() < 2: return
    var r := Rect2(Vector2.ZERO, size)
    draw_rect(r, Color(0, 0, 0, 0.5))
    var left := t - seconds

    var a := PackedVector2Array()
    var b := PackedVector2Array()
    for j in fps.size():
        var x := ((times[j] - left) / seconds) * r.size.x
        a.append(Vector2(x, r.size.y - clamp(fps[j] / fps_max, 0.0, 1.0) * r.size.y))
        b.append(Vector2(x, r.size.y - clamp(ping_ms[j] / ping_max, 0.0, 1.0) * r.size.y))
    draw_polyline(a, Color(1, 1, 0), 2.0, true)   # FPS
    draw_polyline(b, Color(0, 1, 1), 2.0, true)   # Ping
