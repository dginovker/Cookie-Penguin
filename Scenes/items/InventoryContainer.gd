class_name InventoryContainer
extends BaseContainer

func _ready():
    container_type = ContainerType.INVENTORY
    super._ready()

func can_accept_item(item_data: ItemData, slot_index: int) -> bool:
    # Inventory accepts any item type
    return not has_item_at_slot(slot_index)
