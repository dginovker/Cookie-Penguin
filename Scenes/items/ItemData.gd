class_name ItemData
extends Resource

enum ItemType { WEAPON, ARMOR, RING, SIGIL, CONSUMABLE }

@export var id: String
@export var item_name: String
@export var type: ItemType
@export var rarity: int = 0  # 0 = common, 1 = uncommon, 2 = rare, etc.
@export var texture_path: String
@export var stats: Dictionary = {}

func _init(p_id: String = "", p_item_name: String = "", p_type: ItemType = ItemType.CONSUMABLE, p_rarity: int = 0, p_texture_path: String = "", p_stats: Dictionary = {}):
    id = p_id
    item_name = p_item_name
    type = p_type
    rarity = p_rarity
    texture_path = p_texture_path
    stats = p_stats
