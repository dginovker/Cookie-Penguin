extends Area2D
class_name LootBag

@export var despawn_time = 300.0
var items: Array = []
var players_in_range = []

func _ready():
    if multiplayer.is_server():
        body_entered.connect(_on_player_entered)
        body_exited.connect(_on_player_exited)
        get_tree().create_timer(despawn_time).timeout.connect(despawn)

func initialize(spawn_data: Dictionary):
    global_position = spawn_data.position
    items = spawn_data.items

func _on_player_entered(player):
    if not player.is_in_group("players"):
        return
    
    players_in_range.append(player)
    
    # Show loot to the player's HUD
    show_loot_to_player.rpc_id(player.get_multiplayer_authority(), items)

func _on_player_exited(player):
    if not player.is_in_group("players"):
        return
   
    players_in_range.erase(player)
    hide_loot_from_player.rpc_id(player.get_multiplayer_authority())    

@rpc("any_peer", "call_local", "reliable")
func hide_loot_from_player():
    get_tree().get_first_node_in_group("hud").hide_loot_bag()

@rpc("any_peer", "call_local", "reliable")
func show_loot_to_player(loot_items: Array):
    get_tree().get_first_node_in_group("hud").show_loot_bag(loot_items)

func despawn():
    if multiplayer.is_server():
        queue_free()
