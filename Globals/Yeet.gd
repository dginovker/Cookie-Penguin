extends Node

const MOB_LAYER = 2
const PLAYER_LAYER = 4

func serialize_array(data: Array) -> Array[Dictionary]:
    var serial_data: Array[Dictionary] = []
    for obj in data:
        serial_data.append(obj.to_dict())
    return serial_data
