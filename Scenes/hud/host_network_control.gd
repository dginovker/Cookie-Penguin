class_name HudHostNetworkPanel
extends VBoxContainer

@onready var host_network_control: HudHostNetworkPanel = %HostNetworkControl
@onready var backpressure_container: VBoxContainer = $BackpressureScroll/BackpressureContainer

func _process(_delta: float) -> void:
    if not multiplayer.is_server():
        return
    if not host_network_control.visible:
        return

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
            {"id": Net.MOB_HEALTH_UPDATES, "name": "Mob Health"},
            {"id": Net.SERVER_HEALTH_DEBUG_CHANNEL, "name": "Debug Health"}
        ]
        
        for channel in channels:
            var backpressure = Net.get_backpressure(pid, channel.id + 2)
            var channel_label = Label.new()
            channel_label.text = "  Channel %d (%s): %d bytes" % [channel.id, channel.name, backpressure]
            backpressure_container.add_child(channel_label)
        var version_label = Label.new()
        version_label.text = "  Client Version: #%d (%s) " % [PlayerManager.players[pid].client_version, PlayerManager.players[pid].client_version_hash] 
        backpressure_container.add_child(version_label)
        
        # Add spacing between clients
        var spacer = Control.new()
        spacer.custom_minimum_size.y = 10
        backpressure_container.add_child(spacer)
