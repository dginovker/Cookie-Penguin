extends Control

@onready var health_bar = $right_Panel/hp_ProgressBar
@onready var chat_display = $chat_VBoxContainer/chatdisplay_RichTextLabel
@onready var chat_input = $chat_VBoxContainer/chatinput_LineEdit
@onready var inventory_container = $right_Panel/inven_GridContainer

func _ready():
    # Connect chat input
    chat_input.text_submitted.connect(_on_chat_submitted)
    
    # Initialize inventory slots
    setup_inventory_slots()

func update_health(current_health: int, max_health: int):
    health_bar.max_value = max_health
    health_bar.value = current_health

func add_chat_message(player_name: String, message: String):
    var formatted_message = "[color=yellow]%s:[/color] %s\n" % [player_name, message]
    chat_display.append_text(formatted_message)

func _on_chat_submitted(text: String):
    if text.strip_edges() != "":
        var chat_manager = get_tree().get_first_node_in_group("chat_manager")
        chat_manager.send_chat_message.rpc(text)
        chat_input.clear()

func setup_inventory_slots():
    # Create inventory slot buttons
    for i in range(8): # inventory slot count
        var slot_button = TextureButton.new()
        slot_button.custom_minimum_size = Vector2(40, 40)
        slot_button.pressed.connect(_on_inventory_slot_pressed.bind(i))
        inventory_container.add_child(slot_button)

func _on_inventory_slot_pressed(slot_index: int):
    print("Inventory slot %d pressed" % slot_index)

func _input(event):
    # Check if Enter key is pressed and chat input isn't already focused
    if event is InputEventKey and event.pressed:
        if event.keycode == KEY_ENTER and not chat_input.has_focus():
            chat_input.grab_focus()
            # Consume the event so it doesn't get processed by the LineEdit
            get_viewport().set_input_as_handled()
