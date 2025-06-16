# ItemManager.gd - Single manager for all item operations
extends Node

# Server-side inventory tracking
var player_inventories: Dictionary = {}  # peer_id -> {backpack: {}, gear: {}}

func _ready():
    add_to_group("item_manager")

# Server inventory management
func get_player_inventory(peer_id: int) -> Dictionary:
    if not player_inventories.has(peer_id):
        player_inventories[peer_id] = {
            "backpack": {},
            "gear": {},
        }
    return player_inventories[peer_id]

func has_item_at_slot(peer_id: int, container_type: String, slot_index: int) -> bool:
    var inventory = get_player_inventory(peer_id)
    return inventory[container_type].has(slot_index)

func add_item_to_slot(peer_id: int, container_type: String, slot_index: int, item_data: Dictionary):
    var inventory = get_player_inventory(peer_id)
    inventory[container_type][slot_index] = item_data
    print("Server: Added ", item_data.item_name, " to player ", peer_id, " ", container_type, " slot ", slot_index)

func remove_item_from_slot(peer_id: int, container_type: String, slot_index: int) -> Dictionary:
    var inventory = get_player_inventory(peer_id)
    var item_data = inventory[container_type].get(slot_index, {})
    inventory[container_type].erase(slot_index)
    return item_data

func can_accept_item(peer_id: int, container_type: String, slot_index: int, item_data: ItemData) -> bool:
    if has_item_at_slot(peer_id, container_type, slot_index):
        return false
        
    # Gear restrictions
    if container_type == "gear":
        var allowed_types = [
            ItemData.ItemType.WEAPON,   # Slot 0
            ItemData.ItemType.ARMOR,    # Slot 1
            ItemData.ItemType.RING,     # Slot 2
            ItemData.ItemType.SIGIL     # Slot 3
        ]
        
        if slot_index >= allowed_types.size():
            return false
            
        return item_data.type == allowed_types[slot_index]
        
    return true  # Backpack accepts anything

func get_container_type_from_path(container_path: String) -> String:
    if container_path.contains("BackpackVBoxContainer"):
        return "backpack"
    elif container_path.contains("GearVBoxContainer"):
        return "gear"
    return ""

func clear_player_inventory(peer_id: int):
    player_inventories.erase(peer_id)

# Legacy loot pickup functionality
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
    if multiplayer.is_server():
        return
    var hud = get_tree().get_first_node_in_group("hud")
    hud.hide_loot_bag()

# Main item move system
@rpc("any_peer", "call_local", "reliable")
func request_item_move(from_container_path: String, from_slot: int, to_container_path: String, to_slot: int, item_data: Dictionary):
    if not multiplayer.is_server():
        return
    
    var peer_id = multiplayer.get_remote_sender_id()
    var from_container_type = get_container_type_from_path(from_container_path)
    var to_container_type = get_container_type_from_path(to_container_path)
    
    # Loot pickup
    if from_container_path.contains("LootVBoxContainer"):
        var item_definition = ItemRegistry.get_item_data(item_data.item_name)
        if not item_definition or not can_accept_item(peer_id, to_container_type, to_slot, item_definition):
            reject_item_move.rpc_id(peer_id, from_container_path, from_slot, to_container_path, to_slot, "cannot place item there")
            return
        
        # Remove from loot bag
        var loot_bags = get_tree().get_nodes_in_group("loot_bags")
        var item_found = false
        for bag in loot_bags:
            if item_data.id in bag.items_by_id:
                bag.remove_item_by_id(item_data.id)
                item_found = true
                break
        
        if not item_found:
            reject_item_move.rpc_id(peer_id, from_container_path, from_slot, to_container_path, to_slot, "item no longer available")
            return
        
        add_item_to_slot(peer_id, to_container_type, to_slot, item_data)
    else:
        # Container-to-container move
        if not has_item_at_slot(peer_id, from_container_type, from_slot):
            reject_item_move.rpc_id(peer_id, from_container_path, from_slot, to_container_path, to_slot, "no item in source slot")
            return
        
        var item_definition = ItemRegistry.get_item_data(item_data.item_name)
        if not item_definition or not can_accept_item(peer_id, to_container_type, to_slot, item_definition):
            reject_item_move.rpc_id(peer_id, from_container_path, from_slot, to_container_path, to_slot, "cannot place item there")
            return
        
        remove_item_from_slot(peer_id, from_container_type, from_slot)
        add_item_to_slot(peer_id, to_container_type, to_slot, item_data)
    
    confirm_item_move.rpc_id(peer_id, from_container_path, from_slot, to_container_path, to_slot, item_data)

@rpc("any_peer", "call_local", "reliable") 
func request_drop_to_world(from_container_path: String, from_slot: int, item_data: Dictionary):
    if not multiplayer.is_server():
        return
    
    var peer_id = multiplayer.get_remote_sender_id()
    var from_container_type = get_container_type_from_path(from_container_path)
    
    # Find player
    var player = null
    for p in get_tree().get_nodes_in_group("players"):
        if p.get_multiplayer_authority() == peer_id:
            player = p
            break
    
    if not player:
        return
    
    # Remove from server inventory and create loot bag
    remove_item_from_slot(peer_id, from_container_type, from_slot)
    
    # Create loot bag using the MultiplayerSpawner system
    var spawn_data = {
        "position": player.global_position,
        "items": [item_data]
    }
    
    # Find the loot bag spawner and use it
    var loot_spawner: LootSpawner = get_tree().get_first_node_in_group("loot_spawners")
    loot_spawner.spawn_loot_bag(spawn_data)
    
    confirm_item_removal.rpc_id(peer_id, from_container_path, from_slot)
    
@rpc("authority", "call_local", "reliable")
func confirm_item_move(from_container_path: String, from_slot: int, to_container_path: String, to_slot: int, item_data: Dictionary):
    # Only update containers that aren't loot (since loot is managed separately)
    if not from_container_path.contains("LootVBoxContainer"):
        var from_container = get_node(from_container_path)
        if from_container:
            from_container.remove_item_from_slot(from_slot)
    
    var to_container = get_node(to_container_path)
    if to_container:
        to_container.add_item_to_slot(item_data, to_slot)

@rpc("authority", "call_local", "reliable")
func reject_item_move(_from_container_path: String, _from_slot: int, _to_container_path: String, _to_slot: int, reason: String):
    print("Item move rejected: ", reason)

@rpc("authority", "call_local", "reliable")
func confirm_item_removal(from_container_path: String, from_slot: int):
    var from_container = get_node(from_container_path)
    if from_container:
        from_container.remove_item_from_slot(from_slot)
