extends Node

func get_cooldown(player_id: int) -> float:
    var weapon: ItemInstance = ItemManager.get_item_at(ItemLocation.new(ItemLocation.Type.PLAYER_GEAR, player_id, 0))
    if weapon == null:
        return 0.2
            
    if weapon.item_type == 'tier_0_sword':
        return 0.2
    elif weapon.item_type == 'tier_1_sword':
        return 0.18
    elif weapon.item_type == 'tier_2_sword':
        return 0.16
    
    assert(false, "I don't know the cooldown for " + weapon.item_type)
    return 1
