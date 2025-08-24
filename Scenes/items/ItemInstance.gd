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

func get_texture() -> Texture2D:
    """
    Does this look inefficient to you?
    Could you make a "faster" function with "less lines of code"?
    Good for you!
    I like code readable and obvious.
    """
    if item_type == "health_potion":
        return preload("res://Scenes/items/health_potion.png")
    if item_type == "tier_0_sword":
        return preload("res://Scenes/items/tier_0_sword.png")
    if item_type == "tier_1_sword":
        return preload("res://Scenes/items/tier_1_sword.png")
    if item_type == "tier_2_sword":
        return preload("res://Scenes/items/tier_2_sword.png")
    assert(false, "Didn't find the texture for " + item_type)
    return null

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
