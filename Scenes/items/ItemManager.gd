# ItemManager.gd (Godot singleton)
extends Node

var items: Dictionary = {}  # uuid -> ItemInstance
var location_contents: Dictionary = {}  # loc_container_str -> Array[uuid]

func add_item(item: ItemInstance) -> void:
    assert(multiplayer.is_server())
    assert(!items.has(item.uuid), "Server is trying to add item " + str(item) + ", but that uuid exists")
    
    items[item.uuid] = item
    var loc_key = item.location.get_container()
    if not location_contents.has(loc_key):
        location_contents[loc_key] = []
    location_contents[loc_key].append(item.uuid)

func move_item(item_uuid: String, new_location: ItemLocation) -> bool:
    assert(multiplayer.is_server())
    var item = items[item_uuid]
    
    # Remove from old location
    var old_loc_key = item.location.get_container()
    if not old_loc_key in location_contents:
        return false
    location_contents[old_loc_key].erase(item_uuid)
    
    # Add to new location
    item.location = new_location
    var new_loc_key = new_location.get_container()
    if not location_contents.has(new_loc_key):
        location_contents[new_loc_key] = []
    location_contents[new_loc_key].append(item_uuid)
    return true

func get_location_items(location: ItemLocation) -> Array[ItemInstance]:
    assert(multiplayer.is_server())
    var loc_key = location.get_container()
    var result: Array[ItemInstance] = []
    if location_contents.has(loc_key):
        for uuid in location_contents[loc_key]:
            result.append(items[uuid])
    return result
    
@rpc("any_peer", "call_remote", "reliable")
func request_move_item(item_uuid: String, new_location_string: String):
    assert(multiplayer.is_server())
    var new_location: ItemLocation = ItemLocation.from_string(new_location_string)
    var requested_item: ItemInstance = items[item_uuid]
    var original_location = requested_item.location
    
    # Validate if we can move the item
    if original_location.type != ItemLocation.Type.LOOTBAG and original_location.owner_id != new_location.owner_id:
        print("Player doesn't have permission to move item from ", original_location)
        return
    
    if not move_item(item_uuid, new_location):
        print("Failed to move ", item_uuid, " to ", new_location)
        return
        
    if original_location.type == ItemLocation.Type.LOOTBAG:
        # Notify all viewers of the lootbag
        var lootbag: LootBag = LootBag.lootbags[original_location.owner_id]
        lootbag.broadcast_lootbag_update()

    if new_location.type == ItemLocation.Type.PLAYER_BACKPACK:
        # Notify the player to update their backpack
        var player_items = get_player_backpack(new_location.owner_id)
        var item_data: Array[Dictionary] = []
        for item in player_items:
            item_data.append(item.to_dict())
        send_player_backpack.rpc_id(new_location.owner_id, item_data)

func get_player_backpack(player_id: int) -> Array[ItemInstance]:
    var location = ItemLocation.new(ItemLocation.Type.PLAYER_BACKPACK, player_id)
    return get_location_items(location)

@rpc("authority", "call_local")
func send_player_backpack(item_data: Array[Dictionary]):
    assert(!multiplayer.is_server())
    var item_instances: Array[ItemInstance] = []
    for item: Dictionary in item_data:
        item_instances.append(ItemInstance.from_dict(item))
    var hud: HUD = get_tree().get_first_node_in_group("hud")
    hud.inventory_manager.update_backpack(item_instances)
