extends Node

var item_definitions: Dictionary = {}
var texture_cache: Dictionary = {}

func _ready():
    load_item_definitions()

func load_item_definitions():
    # Define all your items here - later you can load from JSON
    item_definitions = {
        "health_potion": ItemData.new(
            "health_potion", 
            "Health Potion", 
            ItemData.ItemType.CONSUMABLE, 
            0, 
            "res://Scenes/items/health_potion.png",
            {"heal": 50}
        ),
        "iron_sword": ItemData.new(
            "iron_sword",
            "Iron Sword",
            ItemData.ItemType.WEAPON,
            0,
            "res://Scenes/items/iron_sword.png",
            {"damage": 10}
        ),
        "leather_armor": ItemData.new(
            "leather_armor",
            "Leather Armor", 
            ItemData.ItemType.ARMOR,
            0,
            "res://Scenes/items/leather_armor.png",
            {"defense": 5}
        ),
        "silver_ring": ItemData.new(
            "silver_ring",
            "Silver Ring",
            ItemData.ItemType.RING,
            1,
            "res://Scenes/items/silver_ring.png",
            {"magic": 3}
        ),
        "fire_sigil": ItemData.new(
            "fire_sigil",
            "Fire Sigil",
            ItemData.ItemType.SIGIL,
            2,
            "res://Scenes/items/fire_sigil.png",
            {"fire_damage": 15}
        )
    }

func get_item_data(item_name: String) -> ItemData:
    return item_definitions.get(item_name)

func get_texture(item_name: String) -> Texture2D:
    if texture_cache.has(item_name):
        return texture_cache[item_name]
    
    var item_data = get_item_data(item_name)
    if item_data:
        var texture = load(item_data.texture_path)
        texture_cache[item_name] = texture
        return texture
    
    return null

func has_item(item_name: String) -> bool:
    return item_definitions.has(item_name)
