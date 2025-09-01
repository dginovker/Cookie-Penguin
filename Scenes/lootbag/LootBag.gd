extends Area3D
class_name LootBag
# See LootSpawner for spawning a lootbag

@export var lootbag_id: int
var nearby_players: Array[int] = []

func _enter_tree():
    $MultiplayerSynchronizer.add_visibility_filter(_visibility_filter)
    $MultiplayerSynchronizer.update_visibility()

func _visibility_filter(peer_id: int) -> bool:
    var player_state: PlayerManager.PlayerState = PlayerManager.players.get(peer_id, null)
    if not player_state:
        return false
    return player_state.in_map

func _ready():
    LootbagTracker.lootbags[lootbag_id] = self
    if multiplayer.is_server():
        body_entered.connect(_on_player_entered)
        body_exited.connect(_on_player_exited)

        # Snap to the floor
        var query = PhysicsRayQueryParameters3D.create(global_position, global_position + Vector3.DOWN * 1000)
        query.exclude = [self]
        var result = get_world_3d().direct_space_state.intersect_ray(query)
        if result:
            # If we were over the land...
            global_position.y = result.position.y

func _process(_delta: float) -> void:
    if multiplayer.is_server() and len(ItemManager.get_container_items(ItemLocation.Type.LOOTBAG, lootbag_id)) == 0:
        queue_free()

func _on_player_entered(body):
    if body is not Player3D:
        return

    var player: Player3D = body
    nearby_players.append(player.peer_id)

    # Send lootbag contents to player
    var items: Array[ItemInstance] = ItemManager.get_container_items(ItemLocation.Type.LOOTBAG, lootbag_id)
    var item_data: Array[Dictionary] = []
    for item: ItemInstance in items:
        item_data.append(item.to_dict())
    LootbagTracker.send_lootbag_contents.rpc_id(player.peer_id, lootbag_id, item_data)


func _on_player_exited(body):
    if body is not Player3D:
        return

    var player: Player3D = body
    nearby_players.erase(player.peer_id)
    LootbagTracker.hide_lootbag_contents.rpc_id(player.peer_id)

func _exit_tree():
    LootbagTracker.lootbags.erase(lootbag_id)

func broadcast_lootbag_update():
    for player_id in nearby_players:
        LootbagTracker.send_lootbag_contents.rpc_id(player_id, lootbag_id, get_serialized_item_data())

func get_items() -> Array[ItemInstance]:
    return ItemManager.get_container_items(ItemLocation.Type.LOOTBAG, lootbag_id)

func get_serialized_item_data() -> Array[Dictionary]:
    var item_data: Array[Dictionary] = []
    for item: ItemInstance in get_items():
        item_data.append(item.to_dict())
    return item_data
