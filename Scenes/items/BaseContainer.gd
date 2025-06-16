class_name BaseContainer
extends Control

enum ContainerType { INVENTORY, GEAR, LOOT }

@export var container_type: ContainerType
@export var slot_count: int = 8
@onready var grid_container = get_child(1)  # Assumes 2nd child is the GridContainer

var slots: Array = []
var slot_items: Dictionary = {}  # slot_index -> item_data
var empty_slot_texture = preload("res://Scenes/hud/empty_slot.png")

signal item_moved(from_container: BaseContainer, from_slot: int, to_container: BaseContainer, to_slot: int)
signal item_dropped_to_world(item_data: Dictionary, container: BaseContainer, slot: int)

func _ready():
    assert(grid_container is GridContainer, "BaseContainer expected to get a GridContainer, got " + grid_container.get_class())
    slots = grid_container.get_children()
    setup_slots()

func setup_slots():
    for i in range(slots.size()):
        var slot = slots[i]
        slot.gui_input.connect(_on_slot_input.bind(i))

func _on_slot_input(event: InputEvent, slot_index: int):
    if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT:
        return
        
    var slot = slots[slot_index]
    if not slot.is_hovered():
        return
    
    if event.pressed:
        start_drag(slot_index)
    else:
        finish_drag(slot_index)

func start_drag(slot_index: int):
    if not has_item_at_slot(slot_index):
        return
        
    var item_data = get_item_at_slot(slot_index)
    DragManager.start_drag(item_data, self, slot_index)

func finish_drag(slot_index: int):
    DragManager.finish_drag(self, slot_index)

func can_accept_item(item_data: ItemData, slot_index: int) -> bool:
    # Base implementation - override in subclasses for restrictions
    return not has_item_at_slot(slot_index)

func has_item_at_slot(slot_index: int) -> bool:
    return slot_items.has(slot_index)

func get_item_at_slot(slot_index: int) -> Dictionary:
    return slot_items.get(slot_index, {})

func add_item_to_slot(item_data: Dictionary, slot_index: int):
    slot_items[slot_index] = item_data
    update_slot_visual(slot_index)
    print("Added ", item_data, " to slot ", slot_index, " of ", get_class())

func remove_item_from_slot(slot_index: int) -> Dictionary:
    var item_data = slot_items.get(slot_index, {})
    slot_items.erase(slot_index)
    update_slot_visual(slot_index)
    return item_data

func update_slot_visual(slot_index: int):
    var slot = slots[slot_index]
    if has_item_at_slot(slot_index):
        var item_data = get_item_at_slot(slot_index)
        slot.texture_normal = ItemRegistry.get_texture(item_data.item_name)
    else:
        slot.texture_normal = empty_slot_texture

func clear_all_slots():
    slot_items.clear()
    for i in range(slots.size()):
        update_slot_visual(i)

func get_empty_slot() -> int:
    for i in range(slots.size()):
        if not has_item_at_slot(i):
            return i
    return -1
