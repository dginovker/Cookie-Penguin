extends Area2D
class_name LootBag

@export var despawn_time = 300.0
var items: Array = []
var players_in_range = []
var items_by_id: Dictionary = {}  # id -> item_data

func _ready():
    if multiplayer.is_server():
        body_entered.connect(_on_player_entered)
        body_exited.connect(_on_player_exited)
        get_tree().create_timer(despawn_time).timeout.connect(despawn)

func initialize(spawn_data: Dictionary):
    global_position = spawn_data.position
    items = spawn_data.items
    
    # Store items by their unique IDs
    for item in items:
        items_by_id[item.id] = item

func _on_player_entered(player: Player):
    assert(multiplayer.is_server(), "Client is calculating player entered lootbag")
    if not player.is_in_group("players"):
        return

    players_in_range.append(player)
    
    # Show loot to the player's HUD - use current items_by_id
    show_loot_to_player.rpc_id(player.get_multiplayer_authority(), items_by_id.values())

func _on_player_exited(player: Player):
    assert(multiplayer.is_server(), "Client is calculating player leaving lootbag")
    if not player.is_in_group("players"):
        return
    
    players_in_range.erase(player)
    
    # Hide loot from player's HUD
    ItemManager.hide_loot_from_player.rpc_id(player.get_multiplayer_authority())

@rpc("any_peer", "call_local", "reliable")
func show_loot_to_player(loot_items: Array):
    assert(!multiplayer.is_server(), "The server doesn't have a HUD; this is supposed to be called on the client!")
    var hud: HUD = get_tree().get_first_node_in_group("hud")
    hud.show_loot_bag(loot_items)

@rpc("authority", "call_local", "reliable")
func remove_item_by_id(item_id: String):
    if not item_id in items_by_id:
        return
        
    items_by_id.erase(item_id)
    
    # Update displays for nearby players
    var remaining_items = items_by_id.values()
    for player in players_in_range:
        show_loot_to_player.rpc_id(player.get_multiplayer_authority(), remaining_items)
    
    # Despawn if empty
    if items_by_id.is_empty():
        queue_free()

func despawn():
    if multiplayer.is_server():
        queue_free()
