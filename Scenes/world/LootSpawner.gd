extends MultiplayerSpawner
class_name LootSpawner

func _ready():
    spawn_function = spawn_loot_custom

func spawn_loot_custom(spawn_data: Dictionary):
    # spawn_data.position is the location of the lootbag
    # spawn_data.items are the name of items to spawn
    var loot_bag_scene = preload("res://Scenes/lootbag/LootBag.tscn")
    var loot_bag: LootBag = loot_bag_scene.instantiate()
    loot_bag.position = spawn_data.position

    # Spawn the items
    if multiplayer.is_server():
        loot_bag.lootbag_id = randi()
        for i in range(len(spawn_data.items)):
            var item := ItemInstance.new(spawn_data.items[i], ItemLocation.new(ItemLocation.Type.LOOTBAG, loot_bag.lootbag_id, i))
            ItemManager.spawn_item(item)
    
    return loot_bag

func spawn_loot_bag(spawn_data: Dictionary):
    if not multiplayer.is_server():
        return
        
    spawn(spawn_data)
