extends PanelContainer

@onready var close_button: Button = %close
@onready var general_button: Button = %GeneralButton
@onready var general_control: Control = %GeneralControl
@onready var debug_button: Button = %DebugButton
@onready var debug_control: Control = %DebugControl
@onready var client_network_button: Button = %ClientNetworkButton
@onready var client_network_control: VBoxContainer = %ClientNetworkControl
@onready var host_network_button: Button = %HostNetworkButton
@onready var host_network_control: VBoxContainer = %HostNetworkControl
@onready var scaling_value_label: Label = %ScalingValue

func _ready() -> void:
    close_button.connect("pressed", func(): self.visible = false)
    general_button.connect("pressed", func(): _turn_off_controls(); general_control.visible = true)
    debug_button.connect("pressed", func(): _turn_off_controls(); debug_control.visible = true)
    host_network_button.connect("pressed", func(): _turn_off_controls(); host_network_control.visible = true)
    client_network_button.connect("pressed", func(): _turn_off_controls(); client_network_control.visible = true)

    _setup_scaling_controls()
func _turn_off_controls():
    general_control.visible = false
    debug_control.visible = false
    host_network_control.visible = false
    client_network_control.visible = false

func _setup_scaling_controls() -> void:
    var scaling_slider: HSlider = get_node("vbox/Panel/GeneralControl/ScalingContainer/ScalingSlider")

    scaling_slider.value = get_viewport().scaling_3d_scale
    _update_scaling_label(scaling_slider.value)

    scaling_slider.connect("value_changed", _on_scaling_changed)

func _on_scaling_changed(value: float) -> void:
    get_viewport().scaling_3d_scale = value
    _update_scaling_label(value)

func _update_scaling_label(value: float) -> void:
    scaling_value_label.text = str(int(value * 100)) + "%"

func _process(_delta: float) -> void:
    %DebugControl/Position.text = "Position: " + str(Vector3i(Yeet.get_local_player().global_position))
