extends MultiplayerSpawner
class_name LootSpawner

func spawn_from_item_list(global_pos: Vector3, dropped_items: Array[String]):
    assert(multiplayer.is_server())
    spawn({
        "position": global_pos,
        "items": dropped_items
    })

func spawn_from_drop_table(global_pos: Vector3, drop_table: Dictionary[String, float]):
    assert(multiplayer.is_server())

    var dropped_items: Array[String] = []

    # Roll each item in the loot table
    for item_name in drop_table:
        if randf() <= drop_table[item_name]:
            dropped_items.append(item_name)

    if dropped_items.is_empty():
        return

    spawn({
        "position": global_pos,
        "items": dropped_items
    })

func _ready():
    spawn_function = _spawn_loot_custom
    despawned.connect(func(n): 
        print("[DESPAWN signal] ", n.get_path(), " class=", n.get_class(), " auth=", n.get_multiplayer_authority()))

func _spawn_loot_custom(spawn_data: Dictionary):
    # { "position": Vector3, "items": Array[String] }
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
