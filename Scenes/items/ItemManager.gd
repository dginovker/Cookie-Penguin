# ItemManager.gd (Godot singleton)
extends Node

var items: Dictionary[String, ItemInstance] = {} # Source of truth on items. uuid -> instance

func spawn_item(item: ItemInstance) -> void:
    assert(multiplayer.is_server(), "Swap item was called by the client. Bad!")
    # Dupe check
    assert(!items.has(item.uuid), "Server is trying to add item " + str(item) + ", but that uuid already exists")
    items[item.uuid] = item
    # Todo - Assert there's no 2 items at the same location

func swap_item(item_uuid: String, target_location: ItemLocation) -> bool:
    assert(multiplayer.is_server())
    var og_item: ItemInstance = items[item_uuid]
    if get_item_at(target_location) != null:
        get_item_at(target_location).location = og_item.location
    og_item.location = target_location
    # Todo - Assert there's no 2 items in the same location
    return true

@rpc("any_peer", "call_local", "reliable")
func request_move_item(item_uuid: String, new_location_string: String):
    assert(multiplayer.is_server())
    var new_location: ItemLocation = ItemLocation.from_string(new_location_string)
    var requested_item: ItemInstance = items[item_uuid]
    var original_location = requested_item.location

    # Validate if we can move the item
    if original_location.type != ItemLocation.Type.LOOTBAG and original_location.owner_id != new_location.owner_id:
        print("Player doesn't have permission to move item from ", original_location)
        return

    if not swap_item(item_uuid, new_location):
        print("Failed to move ", item_uuid, " to ", new_location)
        return
    #print("Move from ", original_location, " to ", new_location, "success")

    if original_location.type == ItemLocation.Type.LOOTBAG:
        # Notify all viewers of the lootbag
        var lootbag: LootBag = LootbagTracker.lootbags[original_location.owner_id]
        lootbag.broadcast_lootbag_update()

    if original_location.type == ItemLocation.Type.PLAYER_BACKPACK or new_location.type == ItemLocation.Type.PLAYER_BACKPACK:
        request_item_sync(new_location.owner_id)

    if original_location.type == ItemLocation.Type.PLAYER_GEAR or new_location.type == ItemLocation.Type.PLAYER_GEAR:
        request_item_sync(new_location.owner_id)

@rpc("any_peer", "call_local")
func request_spawn_lootbag(peer_id: int, item_uuid: String):
    assert(multiplayer.is_server())
    var loc: Vector3 = PlayerManager.players[peer_id].player.global_position
    var loot_spawner: LootSpawner = get_tree().get_first_node_in_group("loot_spawners")
    var original_item: ItemInstance = items[item_uuid]
    # Delete original item
    items.erase(original_item.uuid)
    # Spawn a new one
    loot_spawner.spawn_from_item_list(loc, [original_item.item_type])
    request_item_sync(peer_id)

@rpc("any_peer", "call_local", "reliable")
func request_item_sync(peer_id: int):
    assert(multiplayer.is_server(), "Clients should only request the server for their item sync!")
    var gear_items: Array[Dictionary] = Yeet.serialize_array(get_container_items(ItemLocation.Type.PLAYER_GEAR, peer_id))
    update_player_gear.rpc_id(peer_id, gear_items)

    var backpack_items: Array[Dictionary] = Yeet.serialize_array(get_container_items(ItemLocation.Type.PLAYER_BACKPACK, peer_id))
    update_player_backpack.rpc_id(peer_id, backpack_items)

@rpc("authority", "call_local")
func update_player_backpack(item_data: Array[Dictionary]):
    var item_instances: Array[ItemInstance] = []
    for item: Dictionary in item_data:
        item_instances.append(ItemInstance.from_dict(item))
    var hud: HUD = get_tree().get_first_node_in_group("hud")
    hud.inventory_manager.update_backpack(item_instances)

@rpc("authority", "call_local")
func update_player_gear(item_data: Array[Dictionary]):
    var item_instances: Array[ItemInstance] = []
    for item: Dictionary in item_data:
        item_instances.append(ItemInstance.from_dict(item))
    var hud: HUD = get_tree().get_first_node_in_group("hud")
    hud.inventory_manager.update_gear(item_instances)

@rpc("any_peer", "call_local")
func activate(uuid: String):
    assert(multiplayer.is_server())
    assert(ItemManager.items.has(uuid), "Trying to activate an item that doesn't exist")
    var item: ItemInstance = ItemManager.items[uuid]
    assert(item.location.owner_id == multiplayer.get_remote_sender_id() or item.location.type == ItemLocation.Type.LOOTBAG)
    var player: Player3D = PlayerManager.players[multiplayer.get_remote_sender_id()].player
    print("yay")
    if item.item_type == "health_potion":
        ItemManager.items.erase(uuid)
        if item.location.type == ItemLocation.Type.LOOTBAG:
            LootbagTracker.lootbags[item.location.owner_id].broadcast_lootbag_update()
        else:
            ItemManager.request_item_sync(multiplayer.get_remote_sender_id())
        player.health = min(player.health + 100, player.max_health)
        var net_director: NetDirector = get_tree().get_first_node_in_group("realm_net_director")
        net_director.stats.buffer_stat_update(player)
        return
    if ItemManager.items[uuid].item_type == "tier_0_sword":
        # Todo - equip
        return
    if ItemManager.items[uuid].item_type == "tier_1_sword":
        # Todo - equip
        return
    if ItemManager.items[uuid].item_type == "tier_2_sword":
        # Todo - equip
        return
    print("No activation for ", ItemManager.items[uuid].item_type)



func get_item_at(location: ItemLocation) -> ItemInstance:
    # Todo - This function is extremely inefficient.
    # We need to have an indexing system that maps location -> item
    # and updates each time an item location is set.
    for item: ItemInstance in items.values():
        if str(item.location) == str(location): # str so we don't check pointer
            return item
    return null

func get_container_items(container_type: ItemLocation.Type, owner_id: int) -> Array[ItemInstance]:
    # Todo - this can be optimized via same approach as above.
    var container_items: Array[ItemInstance] = []
    for item: ItemInstance in items.values():
        if item.location.type == container_type and item.location.owner_id == owner_id:
            container_items.append(item)
    return container_items
