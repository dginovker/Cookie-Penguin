extends Node
# See LootSpawner for spawning a lootbag

var lootbags: Dictionary[int, LootBag] = {}

@rpc("authority", "call_local")
func hide_lootbag_contents():
    # Client update
    var hud: HUD = get_tree().get_first_node_in_group("hud")
    hud.hide_loot_bag()


@rpc("authority", "call_local", "reliable", 69)
func send_lootbag_contents(lootbag_id: int, item_data: Array[Dictionary]):
    # Client update
    var items: Array[ItemInstance] = []
    for item: Dictionary in item_data:
        items.append(ItemInstance.from_dict(item))
    var hud: HUD = get_tree().get_first_node_in_group("hud")
    hud.show_loot_bag(lootbag_id, items)
