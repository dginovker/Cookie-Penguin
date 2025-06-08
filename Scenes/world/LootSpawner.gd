extends MultiplayerSpawner

func _ready():
    spawn_function = spawn_loot_custom

func spawn_loot_custom(spawn_data: Array):
    var data = spawn_data[0] as Dictionary
    
    var loot_bag_scene = preload("res://Scenes/lootbag/LootBag.tscn")
    var loot_bag = loot_bag_scene.instantiate()
    
    loot_bag.initialize(data)
    
    return loot_bag

func spawn_loot_bag(spawn_data: Dictionary):
    if not multiplayer.is_server():
        return
    
    print("Trying to spawn with data " + str(spawn_data))
    spawn([spawn_data])
