class_name HUD
extends Control

var player: Player3D # the player this HUD is for

@onready var level_label = %level_label
@onready var health_bar = %hp_ProgressBar
@onready var health_text = %hp_HealthText
@onready var xp_bar = %xp_ProgressBar
@onready var xp_text = %xp_XpText
@onready var chat_display = %chatdisplay_RichTextLabel
@onready var chat_input = %chatinput_LineEdit
@onready var inventory_manager: InventoryManager = %InventoryManager
@onready var items_container: PanelContainer = %TopRightContainer
@onready var inven_button: TextureButton = %InvenButton
@onready var inven_button_panel: Panel = %InvenButtonPanel
@onready var stats_button: TextureButton = %StatsButton
@onready var stats_button_panel: Panel = %StatsButtonPanel

var _inv_panel_stylebox: StyleBoxFlat
var _stats_panel_stylebox: StyleBoxFlat

const BASE_SIZE: Vector2i = Vector2i(1152, 648)
const FONT_AT_2X: float = 1

const FONT_CLASSES: Array[StringName] = [
    StringName("Label"), StringName("Button"), StringName("CheckBox"),
    StringName("LineEdit"), StringName("TextEdit"), StringName("OptionButton"),
    StringName("MenuButton"), StringName("SpinBox"), StringName("ItemList"),
    StringName("Tree"), StringName("Tabs"), StringName("TabBar")
]

var theme_local: Theme
var base_font_size: Dictionary[StringName, int] = {} # per-class baselines
var base_default_font: int

func _ready():
    chat_input.text_submitted.connect(_on_chat_submitted)

    _inv_panel_stylebox = inven_button_panel.get_theme_stylebox("panel")
    _stats_panel_stylebox = stats_button_panel.get_theme_stylebox("panel")
    inven_button.pressed.connect(_inven_button_pressed)
    stats_button.pressed.connect(_stats_button_pressed)

    assert(theme != null) # this node must own a Theme
    theme_local = theme.duplicate()
    theme = theme_local
    # If inheritance is messy across layers, uncomment the next line to force it globally:
    # ThemeDB.set_project_theme(theme_local)

    _cache_font_baselines()
    _apply_theme_scale()
    get_viewport().connect("size_changed", Callable(self, "_apply_theme_scale"))

func _cache_font_baselines() -> void:
    base_font_size.clear()
    for cls in FONT_CLASSES:
        base_font_size[cls] = theme_local.get_font_size(StringName("font_size"), cls)
    base_default_font = theme_local.default_font_size

func _apply_theme_scale() -> void:
    var win: Vector2i = get_window().size
    var k_ui: float = min(float(win.x) / float(BASE_SIZE.x), float(win.y) / float(BASE_SIZE.y))
    var dpr: float = DisplayServer.screen_get_scale()

    # Cancel HiDPI inflation for paddings/margins; stay crisp
    theme_local.default_base_scale = 1.0 / dpr

    # Solve exponent so s(2) = FONT_AT_2X, then cancel DPR for fonts too
    var a: float = log(FONT_AT_2X) / log(2.0)
    var s_font: float = pow(k_ui, a) / dpr

    for cls in FONT_CLASSES:
        theme_local.set_font_size(StringName("font_size"), cls, max(1, int(round(float(base_font_size[cls]) * s_font))))
    theme_local.default_font_size = max(1, int(round(float(base_default_font) * s_font)))
    
func _process(_delta: float) -> void:
    # Boohoo, inefficient?
    # Stop playing with "signals" and race conditions with levelup RPCs. Write clean code and use the profiler.
    # Yeah. I win ALL the arguments with myself in the shower.
    update_stats(int(player.xp), int(player.speed*2), player.attack, int(player.max_health))
    update_health(int(player.health), (player.max_health))
    _update_debug()

func show_loot_bag(lootbag_id: int, loot_items: Array[ItemInstance]):
    inventory_manager.show_loot_bag(lootbag_id, loot_items)

func hide_loot_bag():
    inventory_manager.hide_loot_bag()

func update_health(current_health: float, max_health: float):
    health_bar.max_value = max_health
    health_bar.value = current_health
    health_text.text = "%d/%d" % [current_health, max_health]

func update_xp(xp: int):
    var level := LevelsMath.get_level(xp)
    level_label.text = "Level " + str(level)
    xp_bar.value = xp
    xp_bar.max_value = LevelsMath.xp_for_level(level + 1)
    xp_text.text = "%d/%d" % [xp, LevelsMath.xp_for_level(level + 1)]

func update_stats(xp: int, speed: int, attack: int, life: int):
    var statsbox := %StatsVbox
    (statsbox.get_node("Fighting") as Label).text = "Fighting Level: " + str(LevelsMath.get_level(xp))
    (statsbox.get_node("Speed") as Label).text = "Speed: " + str(speed)
    (statsbox.get_node("Attack") as Label).text = "Attack: " + str(attack)
    (statsbox.get_node("Life") as Label).text = "Life: " + str(life)

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

const FOCUS_COLOR := Color("414141")
const UNFOCUS_COLOR := Color("666666")
func _inven_button_pressed():
    if _inv_panel_stylebox.bg_color.is_equal_approx(FOCUS_COLOR):
        # Inven was already focused, make the topright panel disappear
        %TopRightContainer.visible = false
        _inv_panel_stylebox.bg_color = UNFOCUS_COLOR
    else:
        %TopRightContainer.visible = true
        _stats_panel_stylebox.bg_color = UNFOCUS_COLOR
        _inv_panel_stylebox.bg_color = FOCUS_COLOR
        %StatsVbox.visible = false
        %InvenVbox.visible = true

func _stats_button_pressed():
    if _stats_panel_stylebox.bg_color.is_equal_approx(FOCUS_COLOR):
        # Inven was already focused, make the topright panel disappear
        %TopRightContainer.visible = false
        _stats_panel_stylebox.bg_color = UNFOCUS_COLOR
    else:
        %TopRightContainer.visible = true
        _stats_panel_stylebox.bg_color = FOCUS_COLOR
        _inv_panel_stylebox.bg_color = UNFOCUS_COLOR
        %InvenVbox.visible = false
        %StatsVbox.visible = true

func _update_debug():
    $RootSplit/Right/TopRightContainer/StatsVbox/Position.text = "Position: " + str(Vector3i(player.global_position))
