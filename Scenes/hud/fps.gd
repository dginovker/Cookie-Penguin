extends Control

const UPDATE_INTERVAL = 0.1
const SECONDS := 60.0

var t := 0.0
var times := PackedFloat32Array()
var fps := Array()
var ping_ms := Array()

@onready var fps_label := $Fps
@onready var ping_label := $Ping
@onready var graph := $Grapf

func _ready() -> void:
    set_process(true)

var _timing_uwu := 0.0
func _process(delta: float) -> void:
    _timing_uwu -= delta
    if _timing_uwu > 0:
        return
    _timing_uwu = UPDATE_INTERVAL
    
    t += delta
    times.append(t)
    fps.append(int(1.0 / delta))
    ping_ms.append(NetworkTime.remote_rtt)

    var cut := t - SECONDS
    var i := 0
    while i < times.size() and times[i] < cut: i += 1
    if i > 0:
        times = times.slice(i)
        fps = fps.slice(i)
        ping_ms = ping_ms.slice(i)

    if times.size() % 10 == 0:
        graph.set_data(times, fps, ping_ms, t)
        fps_label.text = " %d FPS   min: %d" % [
            fps.back(), fps.min()
        ]
        ping_label.text = " ping: %d ms   max: %d ms" % [
            int(NetworkTime.remote_rtt), int(ping_ms.max())
        ]
