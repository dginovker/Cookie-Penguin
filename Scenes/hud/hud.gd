extends Control

@onready var health_bar = $PanelContainer/right_Panel/hp_ProgressBar
@onready var chat_display = $chat_VBoxContainer/chatdisplay_RichTextLabel
@onready var chat_input = $chat_VBoxContainer/chatinput_LineEdit
@onready var inventory_container = $PanelContainer/right_Panel/inven_GridContainer
@onready var loot_container = $PanelContainer/right_Panel/loot_VBoxContainer/GridContainer

var inventory_slots = []
var health_potion_texture = preload("res://Scenes/items/health_potion.png")
var empty_slot_texture = preload("res://Scenes/hud/empty_slot.png")
var dragging_item = null

func _ready():
    add_to_group("hud")
    chat_input.text_submitted.connect(_on_chat_submitted)
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
        button.set_meta("item_name", item.item_name)
        button.gui_input.connect(_on_loot_input)
        loot_container.add_child(button)

func _on_loot_input(event: InputEvent):
    if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT:
        return
    
    var button = loot_container.get_children().filter(func(c): return c.is_hovered())[0] if loot_container.get_children().any(func(c): return c.is_hovered()) else null
    if not button:
        return
    
    if event.pressed:
        dragging_item = {"button": button, "item_name": button.get_meta("item_name")}
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
            dragging_item.button.queue_free()
            break
    
    dragging_item.button.z_index = 0
    dragging_item = null

func _process(_delta):
    if dragging_item:
        dragging_item.button.global_position = get_global_mouse_position() - Vector2(20, 20)

func update_health(current_health: int, max_health: int):
    health_bar.max_value = max_health
    health_bar.value = current_health

func add_chat_message(player_name: String, message: String):
    chat_display.append_text("[color=yellow]%s:[/color] %s\n" % [player_name, message])

func _on_chat_submitted(text: String):
    if text.strip_edges() != "":
        get_tree().get_first_node_in_group("chat_manager").send_chat_message.rpc(text)
        chat_input.clear()

func _input(event):
    if event is InputEventKey and event.pressed and event.keycode == KEY_ENTER and not chat_input.has_focus():
        chat_input.grab_focus()
        get_viewport().set_input_as_handled()
