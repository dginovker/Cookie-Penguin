extends Control
class_name InventoryManager

@onready var inventory_container = $InvenVBoxContainer/InvenGridContainer
@onready var loot_container = $LootVBoxContainer/GridContainer

var inventory_slots = []
var health_potion_texture = preload("res://Scenes/items/health_potion.png")
var empty_slot_texture = preload("res://Scenes/hud/empty_slot.png")
var dragging_item = null

signal item_added_to_inventory(item_name: String, slot_index: int)

func _ready():
    inventory_slots = inventory_container.get_children()
    hide_loot_bag()
    
func show_loot_bag(loot_items: Array):
    var loot_buttons = loot_container.get_children()
    
    # Disconnect all existing connections first
    for button in loot_buttons:
        if button.gui_input.is_connected(_on_loot_input):
            button.gui_input.disconnect(_on_loot_input)
    
    # Configure all 8 slots
    for i in range(loot_buttons.size()):
        var button = loot_buttons[i]
        button.visible = true
        
        if i < loot_items.size():
            # Slot has an item
            var item = loot_items[i]
            button.texture_normal = health_potion_texture if item.item_name == "health_potion" else empty_slot_texture
            button.set_meta("item_id", item.id)
            button.set_meta("item_name", item.item_name)
            button.gui_input.connect(_on_loot_input)
        else:
            button.texture_normal = empty_slot_texture
            button.remove_meta("item_id")
            button.remove_meta("item_name")

func hide_loot_bag():
    for button in loot_container.get_children():
        button.visible = false
        if button.gui_input.is_connected(_on_loot_input):
            button.gui_input.disconnect(_on_loot_input)

func _on_loot_input(event: InputEvent):
    if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT:
        return
    
    var button = loot_container.get_children().filter(func(c): return c.is_hovered())[0] if loot_container.get_children().any(func(c): return c.is_hovered()) else null
    if not button:
        return
    
    if event.pressed:
        dragging_item = {"button": button, "item_name": button.get_meta("item_name"), "item_id": button.get_meta("item_id")}
        button.z_index = 100
    else:
        stop_drag()

func stop_drag():
    if not dragging_item:
        return
    
    var mouse_pos = get_global_mouse_position()
    for i in range(inventory_slots.size()):
        var slot = inventory_slots[i]
        if Rect2(slot.global_position, slot.size).has_point(mouse_pos) and slot.texture_normal == empty_slot_texture:
            slot.texture_normal = dragging_item.button.texture_normal
            
            # Tell server to remove this specific item by ID
            get_tree().get_first_node_in_group("loot_manager").request_item_pickup.rpc_id(1, dragging_item.item_id)
            
            dragging_item.button.queue_free()
            item_added_to_inventory.emit(dragging_item.item_name, i)
            break
    
    dragging_item.button.z_index = 0
    dragging_item = null

func _process(_delta):
    if dragging_item:
        dragging_item.button.global_position = get_global_mouse_position() - Vector2(20, 20)
