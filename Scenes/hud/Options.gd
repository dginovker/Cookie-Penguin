extends PanelContainer

@onready var close_button: Button = %close
@onready var general_button: Button = %GeneralButton
@onready var general_control: Control = %GeneralControl
@onready var debug_button: Button = %DebugButton
@onready var debug_control: Control = %DebugControl
@onready var host_network_button: Button = %HostNetworkButton
@onready var host_network_control: VBoxContainer = %HostNetworkControl
@onready var backpressure_container: VBoxContainer

func _ready() -> void:
    close_button.connect("pressed", func(): self.visible = false)
    general_button.connect("pressed", func(): _turn_off_controls(); general_control.visible = true)
    debug_button.connect("pressed", func(): _turn_off_controls(); debug_control.visible = true)
    host_network_button.connect("pressed", func(): _turn_off_controls(); host_network_control.visible = true)
    
    # Set up backpressure monitoring
    backpressure_container = host_network_control.get_node("BackpressureScroll/BackpressureContainer")

func _turn_off_controls():
    general_control.visible = false
    debug_control.visible = false
    host_network_control.visible = false

func _process(_delta: float) -> void:
    %DebugControl/Position.text = "Position: " + str(Vector3i(Yeet.get_local_player().global_position))
    
    # Update backpressure information when host network tab is visible
    if host_network_control.visible and multiplayer.is_server():
        _update_backpressure_display()

func _update_backpressure_display():
    # Clear existing labels
    for child in backpressure_container.get_children():
        child.queue_free()
    
    # Get all connected players
    for pid: int in PlayerManager.players.keys():
        # Add header for this client
        var client_header = Label.new()
        client_header.text = "Client PID: %d" % pid
        client_header.add_theme_font_size_override("font_size", 16)
        backpressure_container.add_child(client_header)
        
        # Add backpressure info for each channel
        var channels = [
            {"id": 0, "name": "Default Reliable"},
            {"id": 1, "name": "Default Unreliable"},
            {"id": 2, "name": "Default Ordered"},
            {"id": Net.SNAPSHOT_CHANNEL, "name": "Snapshot"},
            {"id": Net.SPAWN_CHANNEL, "name": "Spawn"}, 
            {"id": Net.LOOTBAG_CHANNEL, "name": "Lootbag"},
            {"id": Net.MOB_HEALTH_UPDATES, "name": "Mob Health"}
        ]
        
        for channel in channels:
            var backpressure = Net.get_backpressure(pid, channel.id + 2)
            var channel_label = Label.new()
            channel_label.text = "  Channel %d (%s): %d bytes" % [channel.id, channel.name, backpressure]
            channel_label.add_theme_font_size_override("font_size", 12)
            backpressure_container.add_child(channel_label)
        
        # Add spacing between clients
        var spacer = Control.new()
        spacer.custom_minimum_size.y = 10
        backpressure_container.add_child(spacer)
