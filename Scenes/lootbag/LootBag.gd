extends Area3D
class_name LootBag

@export var lootbag_id: int
var nearby_players: Array[int] = []

func _enter_tree():
    $MultiplayerSynchronizer.add_visibility_filter(_visibility_filter)
    $MultiplayerSynchronizer.update_visibility()

func _visibility_filter(other_p: int) -> bool:
    return PlayerManager.map_players.get(other_p, false)

func _ready():
    LootbagManager.lootbags[lootbag_id] = self
    if multiplayer.is_server():
        body_entered.connect(_on_player_entered)
        body_exited.connect(_on_player_exited)

        # Snap to the floor
        var query = PhysicsRayQueryParameters3D.create(global_position, global_position + Vector3.DOWN * 1000)
        query.exclude = [self]
        var result = get_world_3d().direct_space_state.intersect_ray(query)
        global_position.y = result.position.y
    
func _on_player_entered(body):
    if body is not Player3D:
        return
    
    var player: Player3D = body
    nearby_players.append(player.get_multiplayer_authority())
    
    # Send lootbag contents to player
    var items: Array[ItemInstance] = ItemManager.get_container_items(ItemLocation.Type.LOOTBAG, lootbag_id)
    var item_data: Array[Dictionary] = []
    for item: ItemInstance in items:
        item_data.append(item.to_dict())
    send_lootbag_contents.rpc_id(player.get_multiplayer_authority(), item_data)

@rpc("authority", "call_local", "reliable", 69)
func send_lootbag_contents(item_data: Array[Dictionary]):
    var items: Array[ItemInstance] = []
    for item: Dictionary in item_data:
        items.append(ItemInstance.from_dict(item))
    var hud: HUD = get_tree().get_first_node_in_group("hud")
    # I love race conditions
    if len(items) > 0:
        hud.show_loot_bag(lootbag_id, items)
    else:
        hud.hide_loot_bag()
        visible = false

func _on_player_exited(body):
    if body is not Player3D:
        return
        
    var player: Player3D = body
    nearby_players.erase(player.get_multiplayer_authority())
    hide_lootbag_contents.rpc_id(player.get_multiplayer_authority())
    
    if len(nearby_players) == 0 and visible == false:
        await get_tree().create_timer(60).timeout # Race condition tolerance

@rpc("authority", "call_local") 
func hide_lootbag_contents():
    if multiplayer == null:
        # Bag despawned
        return
    var hud: HUD = get_tree().get_first_node_in_group("hud")
    hud.hide_loot_bag()

func _exit_tree():
    LootbagManager.lootbags.erase(lootbag_id)

func broadcast_lootbag_update():
    for player_id in nearby_players:
        send_lootbag_contents.rpc_id(player_id, get_serialized_item_data())
    if len(get_items()) == 0:
        visible = false

func get_items() -> Array[ItemInstance]:
    return ItemManager.get_container_items(ItemLocation.Type.LOOTBAG, lootbag_id)

func get_serialized_item_data() -> Array[Dictionary]:
    var item_data: Array[Dictionary] = []
    for item: ItemInstance in get_items():
        item_data.append(item.to_dict())
    return item_data
