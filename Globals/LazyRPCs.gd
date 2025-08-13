extends Node

# These RPCs are LAZY.. No fancy shenanigans. This means:
# Players who join after the RPC has been called will not see it
# ... probably other caveats that I'll discover as I use them more

const DAMAGE_TEXT := preload("res://Scenes/Uncommon/DamageText/DamageText.tscn")

@rpc("any_peer", "call_local", "unreliable")
func pop(world_pos: Vector3, amount: int, hp_percent: float):
    var dt = DAMAGE_TEXT.instantiate()
    get_tree().get_first_node_in_group("damage_texts").add_child(dt)
    dt.pop(world_pos, amount, hp_percent)
