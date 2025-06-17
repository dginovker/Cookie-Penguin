extends Control
class_name InventoryManager

@onready var inventory_container = $InvenVBoxContainer/InvenGridContainer
@onready var loot_container = $LootVBoxContainer/GridContainer

var inventory_slots = []
var health_potion_texture = preload("res://Scenes/items/health_potion.png")
var empty_slot_texture = preload("res://Scenes/hud/empty_slot.png")
var dragging_item = null

func _ready():
    inventory_slots = inventory_container.get_children()
    hide_loot_bag()
    
func show_loot_bag(loot_items: Array[ItemInstance]):
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
            var item: ItemInstance = loot_items[i]
            # TODO - Fix how we get the texture from ItemInstance
            button.texture_normal = health_potion_texture
            button.set_meta("uuid", item.uuid)
            button.gui_input.connect(_on_loot_input)
        else:
            button.texture_normal = empty_slot_texture
            button.remove_meta("uuid")

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
        dragging_item = {"button": button, "uuid": button.get_meta("uuid")}
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
            # This would update the slot to have the item; instead, let's wait for the server to do this
            # slot.texture_normal = dragging_item.button.texture_normal
            
            # Tell server to remove this specific item by ID
            ItemManager.request_loot_item.rpc_id(1, dragging_item.uuid, multiplayer.multiplayer_peer.get_unique_id())
            
            dragging_item.button.queue_free()
            break
    
    dragging_item.button.z_index = 0
    dragging_item = null

func _process(_delta):
    if dragging_item:
        dragging_item.button.global_position = get_global_mouse_position() - Vector2(20, 20)
