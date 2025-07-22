extends Area2D
class_name LootBag

@export var lootbag_id: int
var nearby_players: Array[int] = []
static var lootbags: Dictionary = {}

func _ready():
    LootBag.lootbags[lootbag_id] = self
    if multiplayer.is_server():
        body_entered.connect(_on_player_entered)
        body_exited.connect(_on_player_exited)

func _on_player_entered(body):
    if body is not Player:
        return
    
    var player: Player = body
    nearby_players.append(player.get_multiplayer_authority())
    
    # Send lootbag contents to player
    var location = ItemLocation.new(ItemLocation.Type.LOOTBAG, lootbag_id)
    var items: Array[ItemInstance] = ItemManager.get_location_items(location)
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
    if body is not Player:
        return
        
    var player: Player = body
    nearby_players.erase(player.get_multiplayer_authority())
    hide_lootbag_contents.rpc_id(player.get_multiplayer_authority())

@rpc("authority", "call_local") 
func hide_lootbag_contents():
    if multiplayer == null:
        # Bag despawned
        return
    assert(!multiplayer.is_server())
    var hud: HUD = get_tree().get_first_node_in_group("hud")
    hud.hide_loot_bag()

func _exit_tree():
    LootBag.lootbags.erase(lootbag_id)

func broadcast_lootbag_update():
    var location = ItemLocation.new(ItemLocation.Type.LOOTBAG, lootbag_id)
    var items: Array[ItemInstance] = ItemManager.get_location_items(location)
    var item_data: Array[Dictionary] = []
    for item: ItemInstance in items:
        item_data.append(item.to_dict())
    for player_id in nearby_players:
        send_lootbag_contents.rpc_id(player_id, item_data)
    if len(items) == 0:
        # TODO - This is a blatant race condition. Remove the sleep to see for yourself
        # This is also causing the Looting Bag to appear visually on the server
        get_tree().create_timer(10).timeout.connect(queue_free)
