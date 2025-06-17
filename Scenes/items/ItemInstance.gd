# ItemInstance.gd
class_name ItemInstance

var uuid: String
var item_type: String
var location: ItemLocation
var custom_data: Dictionary

func _init(type: String = "", loc: ItemLocation = null):
    uuid = generate_uuid()
    item_type = type
    location = loc
    custom_data = {}

# Helpers

static func from_dict(item_data: Dictionary) -> ItemInstance:
    var item = ItemInstance.new()
    item.uuid = item_data.uuid
    item.item_type = item_data.item_type
    item.location = ItemLocation.from_string(item_data.location)
    item.custom_data = item_data.get("custom_data", {})
    return item

# Serialize to dictionary (server-side)
func to_dict() -> Dictionary:
    return {
        "uuid": uuid,
        "item_type": item_type,
        "location": location.to_string(),
        "custom_data": custom_data
    }

func generate_uuid() -> String:
    return "%016x" % [randi()] + "%016x" % [randi()]
