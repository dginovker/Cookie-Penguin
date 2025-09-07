extends VBoxContainer
class_name InventoryManager

# Requires a top-level Control named "DragLayer" (not inside any Container) that fills the viewport.
@onready var drag_layer: Control       = %DragLayer

@onready var top_right_container: PanelContainer = %"TopRightContainer"
@onready var non_inven_stuff: VBoxContainer = %"NonInvenStuff"
@onready var panel_vbox: VBoxContainer   = $".."
@onready var grids := [
    $"GearVBoxContainer/GearGridContainer",
    $"BackpackVBoxContainer/BackpackGridContainer",
    $"LootVBoxContainer/GridContainer",
]

@onready var loot_container  = $LootVBoxContainer/GridContainer
@onready var gear_slots      = $GearVBoxContainer/GearGridContainer.get_children()
@onready var backpack_slots  = $BackpackVBoxContainer/BackpackGridContainer.get_children()
@onready var loot_slots      = $LootVBoxContainer/GridContainer.get_children()

@onready var item_tooltip_panel = %ItemTooltipPanel
@onready var item_tooltip_title = %ItemToolTipTitle
@onready var item_tooltip_text = %ItemToolTipText

var empty_slot_texture = preload("res://Scenes/hud/empty_slot.png")
var current_lootbag_id := -1

# Ghost-drag state
var drag_origin_slot: TextureButton
var drag_origin_rect: Rect2
var drag_item_uuid: String
var drag_item_texture: Texture2D
var drag_ghost: TextureRect
var drag_start_pos: Vector2

const DRAG_THRESHOLD := 6.0

func _ready():
    for g in grids: g.size_flags_vertical = 0
    for i in gear_slots.size():     _wire(gear_slots[i], ItemLocation.Type.PLAYER_GEAR, i)
    for i in backpack_slots.size(): _wire(backpack_slots[i], ItemLocation.Type.PLAYER_BACKPACK, i)
    for i in loot_slots.size():     _wire(loot_slots[i], ItemLocation.Type.LOOTBAG, i)
    hide_loot_bag()

    resized.connect(_request_layout)
    get_viewport().size_changed.connect(_request_layout)
    for g in grids: g.resized.connect(_request_layout)
    call_deferred("_layout")

func _wire(b: TextureButton, t, i):
    b.set_meta("container_type", t)
    b.set_meta("slot_index", i)
    b.gui_input.connect(_on_slot_input.bind(b))

func _request_layout(): call_deferred("_layout")

func _panel_content_size() -> Vector2:
    var vp := get_viewport_rect().size
    var right := top_right_container.get_parent() as Control
    var outer_w := vp.x * (right.anchor_right - right.anchor_left) * (top_right_container.anchor_right - top_right_container.anchor_left)
    var outer_h := vp.y * (top_right_container.anchor_bottom - top_right_container.anchor_top) - non_inven_stuff.size.y
    return Vector2(
        outer_w,
        outer_h
    )

func _layout():
    var panel_content: Vector2 = _panel_content_size()
    var columns := 4

    var total_grid_rows := 0
    for grid in grids:
        var visible_slots = grid.get_children().filter(func(c): return c.visible).size()
        total_grid_rows += int(ceil(float(visible_slots) / columns))

    var grid_h_spacing = grids[0].get_theme_constant("h_separation", "GridContainer")
    var vbox_spacing := panel_vbox.get_theme_constant("separation", "VBoxContainer")
    var hp_bar_height = %hp_ProgressBar.get_combined_minimum_size().y

    var cell_width := int((panel_content.x - grid_h_spacing * (columns - 1)) / columns)
    var cell_height := int((panel_content.y - hp_bar_height - vbox_spacing) / total_grid_rows)

    var cell_size = max(1, min(cell_width, cell_height))  # keeps proportions consistent across aspect ratios

    for grid in grids:
        for button in grid.get_children():
            if button is TextureButton and button.visible:
                button.custom_minimum_size = Vector2(cell_size, cell_size)

    queue_sort()

func show_loot_bag(lootbag_id: int, loot_items: Array[ItemInstance]):
    current_lootbag_id = lootbag_id
    $LootVBoxContainer.visible = true
    var bs = loot_container.get_children()
    for i in bs.size():
        var b: TextureButton = bs[i]
        b.set_meta("lootbag_id", lootbag_id)
        b.visible = true
        if i < loot_items.size():
            var it: ItemInstance = loot_items[i]
            b.texture_normal = it.get_texture()
            b.set_meta("item_instance", it)
        else:
            b.texture_normal = empty_slot_texture
            b.remove_meta("item_instance")
    _request_layout()

func hide_loot_bag():
    current_lootbag_id = -1
    $LootVBoxContainer.visible = false
    _request_layout()

func _on_slot_input(event: InputEvent, slot: TextureButton):
    if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
        return

    if event.double_click and slot.has_meta("item_instance"):
        ItemManager.activate.rpc_id(1, (slot.get_meta("item_instance") as ItemInstance).uuid)
        return

    if event.pressed and slot.has_meta("item_instance"):
        _start_drag(slot)
    else:
        _finish_drag()

func _start_drag(slot: TextureButton):
    item_tooltip_panel.visible = true
    var item: ItemInstance = slot.get_meta("item_instance")
    item_tooltip_title.text = item.item_type
    item_tooltip_text.text = item.item_description()
    drag_origin_slot = slot
    drag_origin_rect = slot.get_global_rect()
    drag_item_uuid = item.uuid
    drag_item_texture = slot.texture_normal
    drag_start_pos = get_global_mouse_position()

func _finish_drag():
    item_tooltip_panel.visible = false
    if drag_origin_slot == null:
        return

    var mouse_pos := get_global_mouse_position()

    # Cancel move if no ghost was created (no real drag) or cursor is within the original rect.
    if drag_ghost == null or drag_origin_rect.has_point(mouse_pos):
        drag_origin_slot.texture_normal = drag_item_texture
        _clear_drag_state()
        return

    var target := _slot_at(mouse_pos)

    if target == null:
        ItemManager.request_spawn_lootbag.rpc_id(1, multiplayer.get_unique_id(), drag_item_uuid)
        _clear_drag_state()
        return

    if target == drag_origin_slot:
        drag_origin_slot.texture_normal = drag_item_texture
        _clear_drag_state()
        return

    var container_type = target.get_meta("container_type")
    var slot_index = target.get_meta("slot_index")
    var player_id = multiplayer.multiplayer_peer.get_unique_id()
    var new_location: ItemLocation = null
    match container_type:
        ItemLocation.Type.PLAYER_BACKPACK:
            new_location = ItemLocation.new(ItemLocation.Type.PLAYER_BACKPACK, player_id, slot_index)
        ItemLocation.Type.PLAYER_GEAR:
            new_location = ItemLocation.new(ItemLocation.Type.PLAYER_GEAR, player_id, slot_index)
        ItemLocation.Type.LOOTBAG:
            var lootbag_id = target.get_meta("lootbag_id")
            new_location = ItemLocation.new(ItemLocation.Type.LOOTBAG, lootbag_id, slot_index)

    ItemManager.request_move_item.rpc_id(1, drag_item_uuid, new_location.to_string())
    _clear_drag_state()

func _slot_at(pos: Vector2) -> TextureButton:
    for s in gear_slots + backpack_slots + loot_slots:
        if s.visible and s.get_global_rect().has_point(pos):
            return s
    return null

func _clear_drag_state():
    if drag_ghost:
        drag_ghost.queue_free()
    drag_ghost = null
    drag_origin_slot = null
    drag_item_uuid = ""
    drag_item_texture = null

func _process(_dt):
    if drag_origin_slot:
        if drag_ghost == null:
            if get_global_mouse_position().distance_to(drag_start_pos) >= DRAG_THRESHOLD:
                drag_ghost = TextureRect.new()
                drag_ghost.texture = drag_item_texture
                drag_ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
                drag_ghost.size = drag_origin_rect.size
                drag_ghost.pivot_offset = drag_ghost.size * 0.5
                drag_layer.add_child(drag_ghost)
                # visually empty the origin while dragging
                drag_origin_slot.texture_normal = empty_slot_texture
        if drag_ghost:
            drag_ghost.global_position = get_global_mouse_position() - drag_ghost.pivot_offset

func update_backpack(items: Array[ItemInstance]):
    for slot in backpack_slots:
        slot.texture_normal = empty_slot_texture
        slot.remove_meta("item_instance")

    for item: ItemInstance in items:
        var slot_index = item.location.slot
        var slot = backpack_slots[slot_index]
        slot.texture_normal = item.get_texture()
        slot.set_meta("item_instance", item)

func update_gear(items: Array[ItemInstance]):
    (%WeaponSlot as TextureButton).texture_normal = preload("res://Scenes/hud/slot_icons/weapon_slot.png")
    %WeaponSlot.remove_meta("item_instance")
    (%AbilitySlot as TextureButton).texture_normal = preload("res://Scenes/hud/slot_icons/ice_barrage_slot.png")
    %AbilitySlot.remove_meta("item_instance")
    (%ArmorSlot as TextureButton).texture_normal = preload("res://Scenes/hud/slot_icons/armor_slot.png")
    %ArmorSlot.remove_meta("item_instance")
    (%RingSlot as TextureButton).texture_normal = preload("res://Scenes/hud/slot_icons/ring_slot.png")
    %RingSlot.remove_meta("item_instance")

    for item: ItemInstance in items:
        var slot_index = item.location.slot
        var slot = gear_slots[slot_index]
        slot.texture_normal = item.get_texture()
        slot.set_meta("item_instance", item)
