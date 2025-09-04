extends Control

const UPDATE_INTERVAL = 0.1
const SECONDS := 60.0

var t := 0.0
var times := PackedFloat32Array()
var fps := Array()
var ping_ms := Array()

@onready var fps_label := $Fps
@onready var ping_label := $Ping
@onready var static_mem_label := $StaticMem
@onready var video_mem_label := $VideoMem
@onready var obj_count_label := $ObjCount
@onready var graph := $Grapf

func _ready() -> void:
    set_process(true)

var _timing_uwu := 0.0
func _process(delta: float) -> void:
    _timing_uwu -= delta
    if _timing_uwu > 0:
        return
    _timing_uwu = UPDATE_INTERVAL
    
    static_mem_label.text = "Static memory (MB): " + str(int(Performance.get_monitor(Performance.MEMORY_STATIC) / 1000_000))
    video_mem_label.text = "Video memory (MB): " + str(int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1000_000))  
    obj_count_label.text = "Obj count: " + str(int(Performance.get_monitor(Performance.OBJECT_COUNT)))
    
    t += delta
    times.append(t)
    fps.append(Performance.get_monitor(Performance.TIME_FPS))
    ping_ms.append(NetworkTime.remote_rtt * 1000)

    var cut := t - SECONDS
    var i := 0
    while i < times.size() and times[i] < cut: i += 1
    if i > 0:
        times = times.slice(i)
        fps = fps.slice(i)
        ping_ms = ping_ms.slice(i)

    if times.size() % 10 == 0:
        graph.set_data(times, fps, ping_ms, t)
        fps_label.text = "%d FPS   min: %d" % [
            fps.back(), fps.min()
        ]
        ping_label.text = "ping: %d ms   max: %d ms" % [
            int(NetworkTime.remote_rtt * 1000), int(ping_ms.max())
        ]
