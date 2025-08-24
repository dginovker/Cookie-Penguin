extends VBoxContainer
class_name InventoryManager

@onready var items_panel: PanelContainer = $"../.."          # Right/TopRightContainer
@onready var items_vbox: VBoxContainer   = $".."
@onready var grids := [
    $"GearVBoxContainer/GearGridContainer",
    $"BackpackVBoxContainer/BackpackGridContainer",
    $"LootVBoxContainer/GridContainer",
]

@onready var loot_container = $LootVBoxContainer/GridContainer
@onready var gear_slots := $GearVBoxContainer/GearGridContainer.get_children()
@onready var backpack_slots := $BackpackVBoxContainer/BackpackGridContainer.get_children()
@onready var loot_slots := $LootVBoxContainer/GridContainer.get_children()

var empty_slot_texture = preload("res://Scenes/hud/empty_slot.png")
var dragging_item = null
var current_lootbag_id := -1

const PAD_Y := 8  # cheap buffer so we don’t fight VBox/labels

func _ready():
    for g in grids: g.size_flags_vertical = 0
    for i in gear_slots.size():     _wire(gear_slots[i], ItemLocation.Type.PLAYER_GEAR, i)
    for i in backpack_slots.size(): _wire(backpack_slots[i], ItemLocation.Type.PLAYER_BACKPACK, i)
    for i in loot_slots.size():     _wire(loot_slots[i], ItemLocation.Type.LOOTBAG, i)
    hide_loot_bag()  # hide the WHOLE section, not just buttons

    resized.connect(_request_layout)
    items_panel.resized.connect(_request_layout)
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
    var right := items_panel.get_parent() as Control
    var outer_w := vp.x * (right.anchor_right - right.anchor_left) * (items_panel.anchor_right - items_panel.anchor_left)   # 20% × TopRightContainer’s width fraction (here 1.0)
    var outer_h := vp.y * (items_panel.anchor_bottom - items_panel.anchor_top)                                              # 70% height in your scene
    var sb := items_panel.get_theme_stylebox("panel", "PanelContainer")
    return Vector2(
        outer_w - sb.get_margin(SIDE_LEFT) - sb.get_margin(SIDE_RIGHT),
        outer_h - sb.get_margin(SIDE_TOP)  - sb.get_margin(SIDE_BOTTOM)
    )

func _layout():
    var content: Vector2 = _panel_content_size()
    var cols := 4

    var total_rows := 0
    for g in grids:
        var vis = g.get_children().filter(func(c): return c.visible).size()
        total_rows += int(ceil(float(vis)/cols))
    if total_rows == 0: return

    var hsep = grids[0].get_theme_constant("h_separation", "GridContainer")
    var vbox_sep := items_vbox.get_theme_constant("separation", "VBoxContainer")
    var hp_h = %hp_TextureProgressBar.get_combined_minimum_size().y

    var cw := int((content.x - hsep*(cols-1)) / cols)
    var ch := int((content.y - hp_h - vbox_sep - PAD_Y) / total_rows)

    var s = max(1, min(cw, ch))  # single scalar; keeps within 20%×70% box in all aspect ratios

    for g in grids:
        for b in g.get_children():
            if b is TextureButton and b.visible: b.custom_minimum_size = Vector2(s, s)

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
            b.set_meta("uuid", it.uuid)
        else:
            b.texture_normal = empty_slot_texture
            b.remove_meta("uuid")
    _request_layout()

func hide_loot_bag():
    current_lootbag_id = -1
    $LootVBoxContainer.visible = false
    _request_layout()

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
    var target_slot: TextureButton = null
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
                if lootbag_id == null:
                    print("Tried to drag item to a lootbag, but the lootbag wasn't there!")
                    return
                new_location = ItemLocation.new(ItemLocation.Type.LOOTBAG, lootbag_id, slot_index)
        print("Requesting move to ", new_location)
        ItemManager.request_move_item.rpc_id(1, dragging_item.get_meta("uuid"), new_location.to_string())
    else:
        # Spawn it as loot
        ItemManager.request_spawn_lootbag.rpc_id(1, multiplayer.get_unique_id(), dragging_item.get_meta("uuid"))
    dragging_item.z_index = 0
    dragging_item.position = dragging_item.get_meta("original_position")
    dragging_item = null

func _process(_delta):
    if dragging_item:
        dragging_item.global_position = get_global_mouse_position() - Vector2(20, 20)

func update_backpack(items: Array[ItemInstance]):
    print("HUD: Updating backpack to have ", items)
    # Clear backpack slots first
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
    # Clear gear slots first
    for slot in gear_slots:
        (%WeaponSlot as TextureButton).texture_normal = preload("res://Scenes/hud/slot_icons/weapon_slot.png")
        %WeaponSlot.remove_meta("uuid")
        (%AbilitySlot as TextureButton).texture_normal = preload("res://Scenes/hud/slot_icons/ice_barrage_slot.png")
        %AbilitySlot.remove_meta("uuid")
        (%ArmorSlot as TextureButton).texture_normal = preload("res://Scenes/hud/slot_icons/armor_slot.png")
        %ArmorSlot.remove_meta("uuid")
        (%RingSlot as TextureButton).texture_normal = preload("res://Scenes/hud/slot_icons/ring_slot.png")
        %RingSlot.remove_meta("uuid")

    # Place each item in its designated slot
    for item: ItemInstance in items:
        var slot_index = item.location.slot
        var slot = gear_slots[slot_index]
        slot.texture_normal = item.get_texture()
        slot.set_meta("uuid", item.uuid)
