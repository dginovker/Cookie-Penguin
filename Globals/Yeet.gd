extends Node

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
