class_name GearContainer
extends BaseContainer

# Slot 0 = Weapon, Slot 1 = Armor, Slot 2 = Ring, Slot 3 = Sigil
var allowed_types = [
    ItemData.ItemType.WEAPON,
    ItemData.ItemType.ARMOR, 
    ItemData.ItemType.RING,
    ItemData.ItemType.SIGIL
]

func _ready():
    container_type = ContainerType.GEAR
    super._ready()

func can_accept_item(item_data: ItemData, slot_index: int) -> bool:
    if has_item_at_slot(slot_index):
        return false
        
    if slot_index >= allowed_types.size():
        return false
        
    return item_data.type == allowed_types[slot_index]
