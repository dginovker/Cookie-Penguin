# ItemInstance.gd
class_name ItemInstance

var uuid: String
var item_type: String
var location: ItemLocation

func _init(type: String = "", loc: ItemLocation = null):
    uuid = generate_uuid()
    item_type = type
    location = loc

# Helpers

static func from_dict(item_data: Dictionary) -> ItemInstance:
    var item = ItemInstance.new()
    item.uuid = item_data.uuid
    item.item_type = item_data.item_type
    item.location = ItemLocation.from_string(item_data.location)
    return item

# Serialize to dictionary (server-side)
func to_dict() -> Dictionary:
    return {
        "uuid": uuid,
        "item_type": item_type,
        "location": location.to_string(),
    }

func generate_uuid() -> String:
    return "%016x" % [randi()] + "%016x" % [randi()]
    
func _to_string() -> String:
    return str(to_dict())
