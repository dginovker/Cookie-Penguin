class_name HUD
extends Control

@onready var health_bar = %hp_TextureProgressBar
@onready var health_text = %hp_HealthText
@onready var chat_display = %chatdisplay_RichTextLabel
@onready var chat_input = %chatinput_LineEdit
@onready var inventory_manager: InventoryManager = %InventoryManager

func _ready():
    add_to_group("hud")
    chat_input.text_submitted.connect(_on_chat_submitted)

func show_loot_bag(lootbag_id: int, loot_items: Array[ItemInstance]):
    inventory_manager.show_loot_bag(lootbag_id, loot_items)

func hide_loot_bag():
    inventory_manager.hide_loot_bag()

func update_health(current_health: int, max_health: int):
    health_bar.max_value = max_health
    health_bar.value = current_health
    health_text.text = "%d/%d" % [current_health, max_health]

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
