extends Area2D
class_name LootBag

@export var lootbag_id: String
var nearby_players: Array[int] = []
# TODO - Implement a static dict of lootbag ids to instances so the lootbag contents can be visually updated for each player when someone loots an item

func _init():
    lootbag_id = generate_lootbag_id()

func _ready():
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
    print("Sending player contents: ", item_data)
    send_lootbag_contents.rpc_id(player.get_multiplayer_authority(), item_data)

@rpc("authority", "call_local")
func send_lootbag_contents(item_data: Array[Dictionary]):
    assert(!multiplayer.is_server())
    var items: Array[ItemInstance] = []
    for item: Dictionary in item_data:
        items.append(ItemInstance.from_dict(item))
    var hud: HUD = get_tree().get_first_node_in_group("hud")
    hud.show_loot_bag(items)

func _on_player_exited(body):
    if body is not Player:
        return
        
    var player: Player = body
    nearby_players.erase(player.get_multiplayer_authority())
    hide_lootbag_contents.rpc_id(player.get_multiplayer_authority())

@rpc("authority", "call_local") 
func hide_lootbag_contents():
    assert(!multiplayer.is_server())
    var hud: HUD = get_tree().get_first_node_in_group("hud")
    hud.hide_loot_bag()

func generate_lootbag_id() -> String:
    return "lootbag_" + str(randi())
