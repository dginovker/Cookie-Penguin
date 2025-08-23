extends Control

const SECONDS: float = 60.0

var t: float = 0.0
var times := PackedFloat32Array()
var fps := Array()

func _ready() -> void:
    set_process(true)

func _process(delta: float) -> void:
    t += delta
    times.append(t)
    fps.append(int(1.0 / delta))
    var cut: float = t - SECONDS
    var i: int = 0
    while i < times.size() and times[i] < cut: i += 1
    if i > 0:
        times = times.slice(i)
        fps = fps.slice(i)
    if len(times) % 10 == 0:
        queue_redraw()

func _draw() -> void:
    var r := Rect2(Vector2.ZERO, size)
    draw_rect(r, Color(0, 0, 0, 0.5))
    if fps.size() < 2: return

    var left_time := t - SECONDS

    var pts := PackedVector2Array()
    for j in fps.size():
        var x := ((times[j] - left_time) / SECONDS) * r.size.x
        var y = r.size.y - clamp(fps[j] / 200.0, 0.0, 1.0) * r.size.y
        pts.append(Vector2(x, y))
    draw_polyline(pts, Color(1, 1, 0), 2.0, true)  # yellow

    var f := get_theme_default_font()
    var fs := get_theme_default_font_size()
    draw_string(
        f,
        Vector2(8, 8 + f.get_height(fs)),
        str(fps[fps.size() - 1], " FPS   min: ", fps.min()),
        HORIZONTAL_ALIGNMENT_LEFT,
        -1.0,
        fs,
        Color.WHITE
    )
