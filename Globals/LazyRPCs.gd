extends Node

# These RPCs are LAZY.. No fancy shenanigans. This means:
# Players who join after the RPC has been called will not see it
# ... probably other caveats that I'll discover as I use them more

const POP_TEXT := preload("res://Scenes/Uncommon/PopText/PopText.tscn")

@rpc("any_peer", "call_local", "unreliable")
func pop_damage(world_pos: Vector3, amount: int, hp_percent: float):
    var text = POP_TEXT.instantiate()
    get_tree().get_first_node_in_group("pop_texts").add_child(text)
    text.pop_damage(world_pos, "-" + str(amount), hp_percent)

@rpc("any_peer", "call_local", "unreliable")
func pop_xp(world_pos: Vector3, xp: int):
    var text = POP_TEXT.instantiate()
    get_tree().get_first_node_in_group("pop_texts").add_child(text)
    text.pop_xp(world_pos, "+" + str(xp) + " XP")
