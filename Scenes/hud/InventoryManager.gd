extends Control
class_name InventoryManager

@onready var gear_container = $GearVBoxContainer/GearGridContainer
@onready var backpack_container = $BackpackVBoxContainer/BackpackGridContainer
@onready var loot_container = $LootVBoxContainer/GridContainer

var backpack_slots = []
var empty_slot_texture = preload("res://Scenes/hud/empty_slot.png")
var dragging_item = null

func _ready():
    backpack_slots = backpack_container.get_children()
    hide_loot_bag()
    
func show_loot_bag(loot_items: Array[ItemInstance]):
    var loot_buttons = loot_container.get_children()
    
    # Disconnect all existing connections first
    for button: TextureButton in loot_buttons:
        if button.gui_input.is_connected(_on_loot_input):
            button.gui_input.disconnect(_on_loot_input)
    
    # Configure all 8 slots
    for i in range(loot_buttons.size()):
        var button: TextureButton = loot_buttons[i]
        button.visible = true
        
        if i < loot_items.size():
            # Slot has an item
            var item: ItemInstance = loot_items[i]
            button.texture_normal = item.get_texture()
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
    for i in range(backpack_slots.size()):
        var slot = backpack_slots[i]
        if Rect2(slot.global_position, slot.size).has_point(mouse_pos) and slot.texture_normal == empty_slot_texture:
            # This would update the slot to have the item; instead, let's wait for the server to do this
            # slot.texture_normal = dragging_item.button.texture_normal
            
            # Tell server to remove this specific item by ID
            ItemManager.request_move_item.rpc_id(1, dragging_item.uuid, ItemLocation.new(ItemLocation.Type.PLAYER_BACKPACK, multiplayer.multiplayer_peer.get_unique_id(), i).to_string())
            break
    
    dragging_item.button.z_index = 0
    dragging_item = null

func _process(_delta):
    if dragging_item:
        dragging_item.button.global_position = get_global_mouse_position() - Vector2(20, 20)

func update_backpack(items: Array[ItemInstance]):        
    # Clear all slots first
    for slot in backpack_slots:
        slot.texture_normal = empty_slot_texture
        slot.remove_meta("uuid")
    
    # Place each item in its designated slot
    for item: ItemInstance in items:
        var slot_index = item.location.slot
        var slot = backpack_slots[slot_index]
        slot.texture_normal = item.get_texture()
        slot.set_meta("uuid", item.uuid)
