extends VBoxContainer

@onready var ping_label := $Ping
func _process(_delta: float) -> void:
    ping_label.text = "ping: %d ms" % [
        int(NetworkTime.remote_rtt * 1000)
    ]
