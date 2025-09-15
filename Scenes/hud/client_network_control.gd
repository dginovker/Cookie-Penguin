extends VBoxContainer

@onready var ping_label := $Ping
@onready var server_physics_fps_label: Label
@onready var server_process_fps_label: Label

var server_health_data: Dictionary = {}

func _ready():
    # Add to group for direct access
    add_to_group("client_network_control")
    
    # Create labels for server health data
    server_physics_fps_label = Label.new()
    server_physics_fps_label.text = "Server Physics FPS: --"
    add_child(server_physics_fps_label)
    
    server_process_fps_label = Label.new()
    server_process_fps_label.text = "Server Process FPS: --"
    add_child(server_process_fps_label)

func _process(_delta: float) -> void:
    ping_label.text = "ping: %d ms" % [
        int(NetworkTime.remote_rtt * 1000)
    ]
    
    # Update server health display
    if server_health_data.has("physics_fps"):
        server_physics_fps_label.text = "Server Physics FPS: %d" % server_health_data["physics_fps"]
    
    if server_health_data.has("process_fps"):
        server_process_fps_label.text = "Server Process FPS: %d" % int(server_health_data["process_fps"])

func _receive_server_health_data(health_data: Dictionary) -> void:
    server_health_data = health_data
