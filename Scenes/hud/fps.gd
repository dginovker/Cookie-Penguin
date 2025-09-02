extends Control

const UPDATE_INTERVAL = 0.2
const SECONDS := 60.0
const SEQ_MOD := 256

var t := 0.0
var times := PackedFloat32Array()
var fps := Array()
var ping_ms := Array()

var _seq := 0
var _sent := PackedInt64Array()
var _rtt_ms := 0

@onready var fps_label := $Fps
@onready var ping_label := $Ping
@onready var graph := $Grapf

func _ready() -> void:
    _sent.resize(SEQ_MOD)
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

    var s := _seq
    _sent[s] = Time.get_ticks_msec()
    ping.rpc_id(1, s)
    _seq = (_seq + 1) % SEQ_MOD
    ping_ms.append(_rtt_ms)

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
            int(_rtt_ms), int(ping_ms.max())
        ]

@rpc("any_peer", "call_local") # server echo; requires same node path on server
func ping(s: int) -> void:
    rpc_id(multiplayer.get_remote_sender_id(), "pong", s)

@rpc("any_peer", "call_local") # client receives; computes RTT
func pong(s: int) -> void:
    _rtt_ms = Time.get_ticks_msec() - _sent[s]
