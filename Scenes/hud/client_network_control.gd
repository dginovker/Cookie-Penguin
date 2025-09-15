class_name HudClientNetworkPanel
extends VBoxContainer

@onready var ping_label := $Ping
@onready var server_physics_fps_label := $ServerPhysicsFps
@onready var server_process_fps_label := $ServerProcessFps
@onready var server_last_health_label := $LastHealthData
@onready var client_backpressure_label := $ClientBackpressure
@onready var server_version_label := $ServerVersion
@onready var client_version_label := $ClientVersion

var server_health_data: Dictionary[String, Variant] = {}
var last_server_health_time: float = -float('inf')

func _process(_delta: float) -> void:
    ping_label.text = "ping: %d ms" % [
        int(NetworkTime.remote_rtt * 1000)
    ]
    
    server_physics_fps_label.text = "Server Physics FPS: %d" % server_health_data.get("physics_fps", -1)
    server_process_fps_label.text = "Server Process FPS: %d" % server_health_data.get("process_fps", -1)    
    client_backpressure_label.text = "Client Backpressure: %d bytes" % server_health_data.get("backpressure", -1)
    server_last_health_label.text = "Last Health Data: %.1fs ago" % (Time.get_ticks_msec() / 1000.0 - last_server_health_time)    
    server_version_label.text = "Server Version: #%d (%s)" % [Yeet.server_version_count, Yeet.server_version_hash]
    client_version_label.text = "Client Version: #%d (%s)" % [GameVersion.COUNT, GameVersion.HASH]

func receive_server_health_data(health_data: Dictionary[String, Variant]) -> void:
    server_health_data = health_data
    last_server_health_time = Time.get_ticks_msec() / 1000.0
