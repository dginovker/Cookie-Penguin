extends PanelContainer

@onready var close_button: Button = %close
@onready var general_button: Button = %GeneralButton
@onready var general_control: Control = %GeneralControl
@onready var debug_button: Button = %DebugButton
@onready var debug_control: Control = %DebugControl
@onready var host_network_button: Button = %HostNetworkButton
@onready var host_network_control: VBoxContainer = %HostNetworkControl

func _ready() -> void:
    close_button.connect("pressed", func(): self.visible = false)
    general_button.connect("pressed", func(): _turn_off_controls(); general_control.visible = true)
    debug_button.connect("pressed", func(): _turn_off_controls(); debug_control.visible = true)
    host_network_button.connect("pressed", func(): _turn_off_controls(); host_network_control.visible = true)

func _turn_off_controls():
    general_control.visible = false
    debug_control.visible = false
    host_network_control.visible = false

func _process(_delta: float) -> void:
    %DebugControl/Position.text = "Position: " + str(Vector3i(Yeet.get_local_player().global_position))
