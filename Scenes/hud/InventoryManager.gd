extends Control
class_name InventoryManager

@onready var loot_container = $LootVBoxContainer/GridContainer
@onready var gear_slots = $GearVBoxContainer/GearGridContainer.get_children()
@onready var backpack_slots = $BackpackVBoxContainer/BackpackGridContainer.get_children()
@onready var loot_slots = $LootVBoxContainer/GridContainer.get_children()

var empty_slot_texture = preload("res://Scenes/hud/empty_slot.png")
var dragging_item = null
var current_lootbag_id: int = -1

func _ready():
    for i in range(gear_slots.size()):
        var slot = gear_slots[i]
        slot.set_meta("container_type", ItemLocation.Type.PLAYER_GEAR)
        slot.set_meta("slot_index", i)
        slot.gui_input.connect(_on_slot_input.bind(slot))

    for i in range(backpack_slots.size()):
        var slot = backpack_slots[i]
        slot.set_meta("container_type", ItemLocation.Type.PLAYER_BACKPACK)
        slot.set_meta("slot_index", i)
        slot.gui_input.connect(_on_slot_input.bind(slot))

    # Loot slots: lootbag_id will be set in show_loot_bag
    for i in range(loot_slots.size()):
        var slot = loot_slots[i]
        slot.set_meta("container_type", ItemLocation.Type.LOOTBAG)
        slot.set_meta("slot_index", i)
        slot.gui_input.connect(_on_slot_input.bind(slot))
    hide_loot_bag()
    
func show_loot_bag(lootbag_id: int, loot_items: Array[ItemInstance]):
    current_lootbag_id = lootbag_id
    var loot_buttons = loot_container.get_children()
        
    # Configure all 8 slots
    for i in range(loot_buttons.size()):
        var button: TextureButton = loot_buttons[i]
        button.set_meta("lootbag_id", lootbag_id)
        button.visible = true
        
        if i < loot_items.size():
            # Slot has an item
            var item: ItemInstance = loot_items[i]
            button.texture_normal = item.get_texture()
            button.set_meta("uuid", item.uuid)
        else:
            button.texture_normal = empty_slot_texture
            button.remove_meta("uuid")

func hide_loot_bag():
    current_lootbag_id = -1
    for button in loot_container.get_children():
        button.visible = false

func _on_slot_input(event: InputEvent, slot):
    if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT:
        return
    if event.pressed:
        if slot.has_meta("uuid"):
            dragging_item = slot
            slot.set_meta("original_position", slot.position)
            slot.z_index = 100
    else:
        stop_drag()

func stop_drag():
    if not dragging_item:
        return
    var mouse_pos = get_global_mouse_position()
    var target_slot = null
    for slot in gear_slots + backpack_slots + loot_slots:
        if slot == dragging_item:
            continue  # Skip the slot being dragged
        if Rect2(slot.global_position, slot.size).has_point(mouse_pos):
            target_slot = slot
            break
    print("Found destination slot ", target_slot)
    if target_slot:
        var container_type = target_slot.get_meta("container_type")
        var slot_index = target_slot.get_meta("slot_index")
        var player_id = multiplayer.multiplayer_peer.get_unique_id()
        var lootbag_id = target_slot.get_meta("lootbag_id") if target_slot.has_meta("lootbag_id") else null
        var new_location = null
        match container_type:
            ItemLocation.Type.PLAYER_BACKPACK:
                new_location = ItemLocation.new(ItemLocation.Type.PLAYER_BACKPACK, player_id, slot_index)
            ItemLocation.Type.PLAYER_GEAR:
                new_location = ItemLocation.new(ItemLocation.Type.PLAYER_GEAR, player_id, slot_index)
            ItemLocation.Type.LOOTBAG:
                new_location = ItemLocation.new(ItemLocation.Type.LOOTBAG, lootbag_id, slot_index)
        ItemManager.request_move_item.rpc_id(1, dragging_item.get_meta("uuid"), new_location.to_string())
        print("Requesting to move to ", new_location)
    dragging_item.z_index = 0
    dragging_item.position = dragging_item.get_meta("original_position")
    dragging_item = null

func _process(_delta):
    if dragging_item:
        dragging_item.global_position = get_global_mouse_position() - Vector2(20, 20)

func update_backpack(items: Array[ItemInstance]):
    print("Updating backpack to have ", items)
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
        
func update_gear(items: Array[ItemInstance]):
    print("Updating gear to have ", items)
    # Clear all slots first
    for slot in gear_slots:
        slot.texture_normal = empty_slot_texture
        slot.remove_meta("uuid")
    
    # Place each item in its designated slot
    for item: ItemInstance in items:
        var slot_index = item.location.slot
        var slot = gear_slots[slot_index]
        slot.texture_normal = item.get_texture()
        slot.set_meta("uuid", item.uuid)
