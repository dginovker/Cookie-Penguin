extends Node

# This is all the stuff I cba to put in it's own autoload
# meow meow

func _ready():
    get_window().content_scale_size = Vector2i(648, 648) # square base helps portrait/landscape
    _apply_scale()
    get_window().size_changed.connect(_apply_scale)

func _apply_scale():
    get_window().content_scale_factor = max(
        get_window().size.y / 648.0,                  # design height
        DisplayServer.screen_get_dpi() / 160.0         # DPI floor (~Android dp baseline)
    )
   
const MOB_LAYER = 2
const PLAYER_LAYER = 4

func serialize_array(data: Array) -> Array[Dictionary]:
    var serial_data: Array[Dictionary] = []
    for obj in data:
        serial_data.append(obj.to_dict())
    return serial_data

func billboard_me(n: Node3D) -> void:
    var b := n.get_viewport().get_camera_3d().global_transform.basis
    n.global_transform.basis = Basis(b.x, b.y, -b.z) # screen-right, screen-up, facing camera
