extends MultiplayerSpawner
class_name LootSpawner

func _ready():
    spawn_function = spawn_loot_custom

func spawn_loot_custom(spawn_data: Dictionary):
    var loot_bag_scene = preload("res://Scenes/lootbag/LootBag.tscn")
    var loot_bag: LootBag = loot_bag_scene.instantiate()
    loot_bag.position = spawn_data.position

    # Spawn the items
    if multiplayer.is_server():
        var item_location = ItemLocation.new(ItemLocation.Type.LOOTBAG, loot_bag.lootbag_id)
        for item: String in spawn_data.items:
            var item_instance = ItemInstance.new(item, item_location)
            ItemManager.add_item(item_instance)
    
    return loot_bag

func spawn_loot_bag(spawn_data: Dictionary):
    if not multiplayer.is_server():
        return
        
    spawn(spawn_data)
