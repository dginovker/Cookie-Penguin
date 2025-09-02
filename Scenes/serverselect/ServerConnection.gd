extends Node

var is_server: bool
const PORT: int = 10000

func _ready() -> void:
    is_server = OS.get_cmdline_args().has("--server") || true
    if !is_server:
        # Join the server
        print("Joining as WebRTC Client..")
        Net.start_client()
        get_window().title = "Client"
    else:
        # We are the server
        PlayerManager.start_listening()
        Net.start_server()
        await get_tree().process_frame # Wait a frame so we don't change scenes during _ready
        var game_scene: Node = load("res://Scenes/3dWorld/3Dworld.tscn").instantiate()
        get_tree().root.add_child(game_scene)
        PlayerManager.spawn_player(1)
        get_window().title = "Server"
        queue_free()  # remove the main menu
