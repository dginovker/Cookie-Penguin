class_name Loot_Manager
extends Node

@rpc("any_peer", "call_local", "reliable")
func request_item_pickup(item_id: String):
    if not multiplayer.is_server():
        return
    
    var loot_bags = get_tree().get_nodes_in_group("loot_bags")
    for bag in loot_bags:
        if item_id in bag.items_by_id:
            bag.remove_item_by_id(item_id)
            break

@rpc("any_peer", "call_local", "reliable")
func hide_loot_from_player():
    assert(!multiplayer.is_server(), "Server has no HUD so it can't hide loot")
    var hud : HUD = get_tree().get_first_node_in_group("hud")
    hud.hide_loot_bag()
