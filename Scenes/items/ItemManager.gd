# ItemManager.gd (Godot singleton)
extends Node

var items: Dictionary = {}  # uuid -> ItemInstance
var location_contents: Dictionary = {}  # location_string -> Array[uuid]

func add_item(item: ItemInstance) -> void:
    assert(multiplayer.is_server())
    assert(!items.has(item.uuid), "Server is trying to add item " + str(item) + ", but that uuid exists")
    
    print("Adding item ", item, " to location ", item.location)
    items[item.uuid] = item
    var loc_key = item.location.to_string()
    if not location_contents.has(loc_key):
        location_contents[loc_key] = []
    location_contents[loc_key].append(item.uuid)

func move_item(item_uuid: String, new_location: ItemLocation) -> bool:
    assert(multiplayer.is_server())
    var item = items[item_uuid]
    
    # Remove from old location
    var old_loc_key = item.location.to_string()
    if not old_loc_key in location_contents:
        return false
    location_contents[old_loc_key].erase(item_uuid)
    
    # Add to new location
    item.location = new_location
    var new_loc_key = new_location.to_string()
    if not location_contents.has(new_loc_key):
        location_contents[new_loc_key] = []
    location_contents[new_loc_key].append(item_uuid)
    return true

func get_location_items(location: ItemLocation) -> Array[ItemInstance]:
    assert(multiplayer.is_server())
    var loc_key = location.to_string()
    var result: Array[ItemInstance] = []
    if location_contents.has(loc_key):
        for uuid in location_contents[loc_key]:
            result.append(items[uuid])
    return result
    
@rpc("any_peer", "call_remote", "reliable")
func request_loot_item(item_uuid: String, player_id: int, slot_id: int):
    assert(multiplayer.is_server())
    # Validate the request
    var requested_item: ItemInstance = items[item_uuid]
    var lootbag_id = requested_item.location.owner_id
    
    # Check if the requested_item is still in a lootbag    
    if requested_item.location.type != ItemLocation.Type.LOOTBAG:
        print("Too late! It's gone.")
        return
    
    # Move item to player's backpack
    var player_backpack = ItemLocation.new(ItemLocation.Type.PLAYER_BACKPACK, player_id, slot_id)
    if move_item(item_uuid, player_backpack):
        # Theory - move item changed the location, so we need to broadcast the original looting bag id?
        print("TODO - Update the player who took it's HUD to show that they now have the item")
        # Notify all viewers of the lootbag
        print("Broadcasting lootbag update for lootbag ", lootbag_id)
        var lootbag: LootBag = LootBag.lootbags[lootbag_id]
        lootbag.broadcast_lootbag_update()
