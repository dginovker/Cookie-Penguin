extends Control

const SECONDS: float = 60.0
const REDRAW_HZ: float = 10.0  # draw ~10 fps, still sample every frame

var t: float = 0.0
var last_draw_t: float = 0.0
var times: PackedFloat32Array = PackedFloat32Array()
var fps: PackedFloat32Array = PackedFloat32Array()

func _ready() -> void:
    set_process(true)

func _process(delta: float) -> void:
    t += delta
    times.append(t)
    fps.append(1.0 / delta)
    var cut: float = t - SECONDS
    var i: int = 0
    while i < times.size() and times[i] < cut: i += 1
    if i > 0:
        times = times.slice(i)
        fps = fps.slice(i)
    if t - last_draw_t >= 1.0 / REDRAW_HZ:
        last_draw_t = t
        queue_redraw()

func _draw() -> void:
    var r := Rect2(Vector2.ZERO, size)
    draw_rect(r, Color(0, 0, 0, 0.5))
    var n := fps.size()
    if n < 2: return

    var left_time := t - SECONDS
    var w := r.size.x
    var h := r.size.y

    var pts := PackedVector2Array()
    for j in n:
        var x := ((times[j] - left_time) / SECONDS) * w
        var y = h - clamp(fps[j] / 200.0, 0.0, 1.0) * h
        pts.append(Vector2(x, y))
    draw_polyline(pts, Color(1, 1, 0), 2.0, true)  # yellow

    var f := get_theme_default_font()
    var fs := get_theme_default_font_size()
    var now_fps := int(round(fps[n - 1]))
    var min_fps := fps[0]
    for j in n:
        var v := fps[j]
        if v < min_fps: min_fps = v
    draw_string(
        f,
        Vector2(8, 8 + f.get_height(fs)),
        str(now_fps, " FPS   min: ", int(round(min_fps))),
        HORIZONTAL_ALIGNMENT_LEFT,
        -1.0,
        fs,
        Color.WHITE
    )
