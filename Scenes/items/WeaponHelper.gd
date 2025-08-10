extends Node

func get_cooldown(player_id: int) -> float:
    var weapon: ItemInstance = ItemManager.get_item_at(ItemLocation.new(ItemLocation.Type.PLAYER_GEAR, player_id, 0))
    if weapon == null:
        return 0.4
            
    if weapon.item_type == 'tier_0_sword':
        return 0.4
    elif weapon.item_type == 'tier_1_sword':
        return 0.35
    elif weapon.item_type == 'tier_2_sword':
        return 0.3
    
    assert(false, "I don't know the cooldown for " + weapon.item_type)
    return 1

func get_bullet_name(player_id: int) -> String:
    var weapon: ItemInstance = ItemManager.get_item_at(ItemLocation.new(ItemLocation.Type.PLAYER_GEAR, player_id, 0))
    if weapon == null:
        return "tier_0_bullet.png"
            
    if weapon.item_type == 'tier_0_sword':
        return "tier_1_bullet.png"
    elif weapon.item_type == 'tier_1_sword':
        return "tier_2_bullet.png"
    elif weapon.item_type == 'tier_2_sword':
        return "tier_3_bullet.png"
    
    assert(false, "I don't know the bullet name for " + weapon.item_type)
    return ""
