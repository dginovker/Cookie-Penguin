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
