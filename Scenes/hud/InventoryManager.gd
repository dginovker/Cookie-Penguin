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

    resized.connect(_layout)
    call_deferred("_layout")
    
func _layout():
    var grids := [$GearVBoxContainer/GearGridContainer, $BackpackVBoxContainer/BackpackGridContainer, $LootVBoxContainer/GridContainer]
    var v_sep := get_theme_constant("separation", "VBoxContainer")
    var hsep := {}; var vsep := {}
    for g in grids:
        hsep[g] = g.get_theme_constant("h_separation", "GridContainer")
        vsep[g] = g.get_theme_constant("v_separation", "GridContainer")

    var rows := {}
    var total_rows := 0
    for g in grids:
        var vis = g.get_children().filter(func(c): return c.visible).size()
        rows[g] = int(ceil(float(vis) / float(g.columns)))
        total_rows += rows[g]

    var non_grid_h := 0
    for slot in get_children():
        if slot is VBoxContainer:
            for n in slot.get_children():
                if n is GridContainer: continue
                non_grid_h += n.size.y
        else:
            non_grid_h += slot.size.y

    var active_grids := grids.filter(func(g): return rows[g] > 0)
    var sep_count = max(active_grids.size() - 1, 0)
    var available_h = size.y - non_grid_h - v_sep * sep_count
    var sep_sum := 0
    for g in active_grids: sep_sum += vsep[g] * max(rows[g] - 1, 0)
    var s_h := int((available_h - sep_sum) / max(total_rows, 1))

    for g in grids:
        if rows[g] == 0: continue
        var s_w := int((g.size.x - hsep[g] * (g.columns - 1)) / g.columns)
        var s = max(1, min(s_w, s_h))
        for b in g.get_children():
            if b is TextureButton and b.visible: b.custom_minimum_size = Vector2(s, s)

    
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
        var new_location: ItemLocation = null
        match container_type:
            ItemLocation.Type.PLAYER_BACKPACK:
                new_location = ItemLocation.new(ItemLocation.Type.PLAYER_BACKPACK, player_id, slot_index)
            ItemLocation.Type.PLAYER_GEAR:
                new_location = ItemLocation.new(ItemLocation.Type.PLAYER_GEAR, player_id, slot_index)
            ItemLocation.Type.LOOTBAG:
                new_location = ItemLocation.new(ItemLocation.Type.LOOTBAG, lootbag_id, slot_index)
        print("Requesting move to ", new_location)
        ItemManager.request_move_item.rpc_id(1, dragging_item.get_meta("uuid"), new_location.to_string())
    dragging_item.z_index = 0
    dragging_item.position = dragging_item.get_meta("original_position")
    dragging_item = null

func _process(_delta):
    if dragging_item:
        dragging_item.global_position = get_global_mouse_position() - Vector2(20, 20)

func update_backpack(items: Array[ItemInstance]):
    print("HUD: Updating backpack to have ", items)
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
