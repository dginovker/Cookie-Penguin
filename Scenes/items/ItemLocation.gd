# ItemLocation.gd
class_name ItemLocation

enum Type {
    PLAYER_BACKPACK,
    PLAYER_EQUIPMENT, 
    LOOTBAG,
    GROUND
}

var type: Type
var owner_id: int  # PlayerID or LootbagID
var slot: int

func _init(loc_type: Type, owner: int, slot_num: int = 0):
    type = loc_type
    owner_id = owner
    slot = slot_num

func _to_string() -> String:
    return "%s:%s:%d" % [Type.keys()[type], owner_id, slot]
    
static func from_string(location_str: String) -> ItemLocation:
    var parts = location_str.split(":")
    var type_enum = Type[parts[0]]
    var owner = int(parts[1])
    var slot_num = int(parts[2])
    return ItemLocation.new(type_enum, owner, slot_num)
