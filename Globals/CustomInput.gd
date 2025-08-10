extends Node

func left_pressed() -> bool: 
    var hud: HUD = get_tree().get_first_node_in_group("hud")
    return Input.is_action_pressed("left") or hud and hud.left.is_pressed()

func right_pressed() -> bool:
    var hud: HUD = get_tree().get_first_node_in_group("hud")
    return Input.is_action_pressed("right") or hud and hud.right.is_pressed()

func up_pressed() -> bool:
    var hud: HUD = get_tree().get_first_node_in_group("hud")
    return Input.is_action_pressed("up") or hud and hud.up.is_pressed()

func down_pressed() -> bool:
    var hud: HUD = get_tree().get_first_node_in_group("hud")
    return Input.is_action_pressed("down") or hud and hud.down.is_pressed()
