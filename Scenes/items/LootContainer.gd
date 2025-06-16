class_name LootContainer  
extends BaseContainer

func _ready():
    container_type = ContainerType.LOOT
    super._ready()

func can_accept_item(_item_data: ItemData, _slot_index: int) -> bool:
    # Loot container is read-only (can't drop items into it)
    return false

func show_loot_items(loot_items: Array):
    clear_all_slots()
    
    for slot in slots:
        slot.visible = true
    
    for i in range(min(loot_items.size(), slots.size())):
        var item = loot_items[i]
        # Use the base class method to properly store the item
        add_item_to_slot(item, i)
        # Store the item_id for server communication
        slots[i].set_meta("item_id", item.id)

func hide_loot_items():
    clear_all_slots()
    for slot in slots:
        slot.visible = false
        if slot.has_meta("item_id"):
            slot.remove_meta("item_id")
