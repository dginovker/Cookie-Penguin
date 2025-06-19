extends Node

static func get_cooldown(player_id: int) -> int:
    var gear: Array[ItemInstance] = ItemManager.get_location_items(ItemLocation.new(ItemLocation.Type.PLAYER_GEAR, player_id))
    var weapon_filter: Array[ItemInstance] = gear.filter(func(g:ItemInstance): return g.location.slot == 0)
    if len(weapon_filter) == 0:
        return 2
    var weapon: ItemInstance = weapon_filter[0]
    
    if weapon.item_type == 'tier_0_sword':
        return 1
    elif weapon.item_type == 'tier_1_sword':
        return 0.5
    elif weapon.item_type == 'tier_2_sword':
        return 0.2
    
    assert(false, "I don't know the cooldown for " + weapon.item_type)
    return 0
