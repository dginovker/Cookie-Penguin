extends Control
class_name InventoryManager

@onready var inventory_container = $inven_GridContainer
@onready var loot_container = $loot_VBoxContainer/GridContainer

var inventory_slots = []
var health_potion_texture = preload("res://Scenes/items/health_potion.png")
var empty_slot_texture = preload("res://Scenes/hud/empty_slot.png")
var dragging_item = null

signal item_added_to_inventory(item_name: String, slot_index: int)

func _ready():
    create_inventory_slots()

func create_inventory_slots():
    for i in range(8):
        var slot = TextureButton.new()
        slot.custom_minimum_size = Vector2(40, 40)
        slot.texture_normal = empty_slot_texture
        slot.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
        inventory_slots.append(slot)
        inventory_container.add_child(slot)

func show_loot_bag(loot_items: Array):
    for child in loot_container.get_children():
        child.queue_free()
    
    for item in loot_items:
        var button = TextureButton.new()
        button.custom_minimum_size = Vector2(40, 40)
        button.texture_normal = health_potion_texture if item.item_name == "health_potion" else null
        button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
        button.set_meta("item_id", item.id)  # Store ID instead of name
        button.set_meta("item_name", item.item_name)
        button.gui_input.connect(_on_loot_input)
        loot_container.add_child(button)

func hide_loot_bag():
    for child in loot_container.get_children():
        child.queue_free()

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

@rpc("any_peer", "reliable")
func request_item_pickup(item_id: String):
    if not multiplayer.is_server():
        return
    
    # Find the loot bag containing this item and remove it
    var loot_bags = get_tree().get_nodes_in_group("loot_bags")
    for bag in loot_bags:
        if item_id in bag.items_by_id:
            bag.remove_item_by_id(item_id)
            break

func _process(_delta):
    if dragging_item:
        dragging_item.button.global_position = get_global_mouse_position() - Vector2(20, 20)
