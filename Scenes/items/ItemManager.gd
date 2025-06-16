extends Node

func _ready():
    add_to_group("item_manager")

# Keep existing loot pickup functionality
@rpc("any_peer", "call_local", "reliable")
func request_item_pickup(item_id: String):
    print("Request item pickup")
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
        return  # Server has no HUD
    var hud = get_tree().get_first_node_in_group("hud")
    hud.hide_loot_bag()

# New unified item move system
@rpc("any_peer", "call_local", "reliable")
func request_item_move(from_container_path: String, from_slot: int, to_container_path: String, to_slot: int, item_data: Dictionary):
    print("Request item move")
    if not multiplayer.is_server():
        return
    
    # Special case: if moving FROM loot, validate against the actual loot bag instead of container
    var from_container = get_node(from_container_path)
    var to_container = get_node(to_container_path)
    
    if not to_container:
        reject_item_move.rpc_id(multiplayer.get_remote_sender_id(), from_container_path, from_slot, to_container_path, to_slot, "invalid destination container")
        return
    
    # Check if this is a loot pickup (from loot container to inventory/gear)
    if from_container_path.contains("LootVBoxContainer"):
        # Handle loot pickup - validate against actual loot bags
        if not validate_loot_pickup(item_data, to_container, to_slot):
            reject_item_move.rpc_id(multiplayer.get_remote_sender_id(), from_container_path, from_slot, to_container_path, to_slot, "cannot pick up that item")
            return
        
        # Remove from loot bag (your existing system)
        var loot_bags = get_tree().get_nodes_in_group("loot_bags")
        var item_found = false
        for bag in loot_bags:
            if item_data.id in bag.items_by_id:
                bag.remove_item_by_id(item_data.id)
                item_found = true
                break
        
        if not item_found:
            reject_item_move.rpc_id(multiplayer.get_remote_sender_id(), from_container_path, from_slot, to_container_path, to_slot, "item no longer available")
            return
    else:
        # Regular container-to-container move
        if not from_container:
            reject_item_move.rpc_id(multiplayer.get_remote_sender_id(), from_container_path, from_slot, to_container_path, to_slot, "invalid source container")
            return
        
        # Validate move rules
        if not can_move_item_server(from_container, from_slot, to_container, to_slot, item_data):
            reject_item_move.rpc_id(multiplayer.get_remote_sender_id(), from_container_path, from_slot, to_container_path, to_slot, "that item can't move there")
            return
        
        # Remove from source container
        from_container.remove_item_from_slot(from_slot)
    
    # Add to destination container (both cases)
    to_container.add_item_to_slot(item_data, to_slot)
    
    # Confirm move to ONLY the requesting player
    confirm_item_move.rpc_id(multiplayer.get_remote_sender_id(), from_container_path, from_slot, to_container_path, to_slot, item_data)

@rpc("any_peer", "call_local", "reliable") 
func request_drop_to_world(from_container_path: String, from_slot: int, item_data: Dictionary):
    if not multiplayer.is_server():
        return
    
    var players = get_tree().get_nodes_in_group("players")
    var player = null
    
    # Find the player who made the request
    for p in players:
        if p.get_multiplayer_authority() == multiplayer.get_remote_sender_id():
            player = p
            break
    
    if not player:
        return
    
    # Create loot bag at player position
    var loot_bag_scene = preload("res://Scenes/lootbag/LootBag.tscn")
    var loot_bag = loot_bag_scene.instantiate()
    
    var spawn_data = {
        "position": player.global_position,
        "items": [item_data]
    }
    
    get_tree().current_scene.add_child(loot_bag)
    loot_bag.initialize(spawn_data)
    
    # Confirm item removal from container to ONLY the requesting player
    confirm_item_removal.rpc_id(multiplayer.get_remote_sender_id(), from_container_path, from_slot)

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
func reject_item_move(from_container_path: String, from_slot: int, to_container_path: String, to_slot: int, reason: String):
    # Item move was rejected - UI should revert any optimistic updates
    print("Item move rejected: ", from_container_path, ":", from_slot, " -> ", to_container_path, ":", to_slot, ". Reason:", reason)

@rpc("authority", "call_local", "reliable")
func confirm_item_removal(from_container_path: String, from_slot: int):
    var from_container = get_node(from_container_path)
    if from_container:
        from_container.remove_item_from_slot(from_slot)

func validate_loot_pickup(item_data: Dictionary, to_container: BaseContainer, to_slot: int) -> bool:
    # Check if destination can accept the item
    var item_definition = ItemRegistry.get_item_data(item_data.item_name)
    if not item_definition:
        return false
    
    return to_container.can_accept_item(item_definition, to_slot)

func can_move_item_server(from_container: BaseContainer, from_slot: int, to_container: BaseContainer, to_slot: int, item_data: Dictionary) -> bool:
    # Server-side validation logic
    if not from_container.has_item_at_slot(from_slot):
        print("Failing move: ", from_container, " doesn't have item in slot ", from_slot)
        return false
    
    var item_definition = ItemRegistry.get_item_data(item_data.item_name)
    if not item_definition:
        print("Failing move: No definition for " + str(item_data))
        return false
    
    return to_container.can_accept_item(item_definition, to_slot)
