extends Node

# These RPCs are LAZY.. No fancy shenanigans. This means:
# Players who join after the RPC has been called will not see it
# ... probably other caveats that I'll discover as I use them more

const POP_TEXT := preload("res://Scenes/Uncommon/PopText/PopText.tscn")

@rpc("any_peer", "call_local", "unreliable")
func pop_damage(path: NodePath, amount: int, hp_percent: float):
    var node := get_node_or_null(path)
    if not node:
        return
    var text = POP_TEXT.instantiate()
    get_tree().get_first_node_in_group("pop_texts").add_child(text)
    text.pop_damage(node, "-" + str(amount), hp_percent)

@rpc("any_peer", "call_local", "unreliable")
func pop_xp(path: NodePath, xp: int):
    var node := get_node_or_null(path)
    if not node:
        return
    var text = POP_TEXT.instantiate()
    get_tree().get_first_node_in_group("pop_texts").add_child(text)
    text.pop_xp(node, "+" + str(xp) + " XP")

@rpc("any_peer", "call_local", "unreliable")
func pop_level(path: NodePath):
    var node := get_node_or_null(path)
    if not node:
        return
    var text = POP_TEXT.instantiate()
    get_tree().get_first_node_in_group("pop_texts").add_child(text)
    text.pop_level(node)
