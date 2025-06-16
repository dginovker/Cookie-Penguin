class_name BackpackContainer
extends BaseContainer

func _ready():
    container_type = ContainerType.BACKPACK
    super._ready()

func can_accept_item(_item_data: ItemData, slot_index: int) -> bool:
    # Backpack accepts any item type
    if has_item_at_slot(slot_index):
        print("Can't move ", _item_data, " to slot ", slot_index, " because something is already there")
        return false 
    return true
