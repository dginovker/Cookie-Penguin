# UIRoot.gd — single owner, single scale. Web == Editor. Late UI safe.
# Fonts + layout via theme; bar thickness via custom_minimum_size.y with gain, hard caps, and no EXPAND.

extends Control

# ---------- knobs ----------
const BASE_SIZE: Vector2i = Vector2i(1152, 648)   # design resolution (logical)
const AT_2X: float = 0.90                         # k_phys doubles -> perceived UI scale multiplies by this (<1 shrinks)
const BAR_AT_2X: float = 1.00                     # independent bar slope (1.00 = flat vs area)
const BAR_GAIN: float = 2                      # fixed multiplier on bar baseline after BAR_AT_2X
const BAR_MAX_FRAC: float = 0.12                  # bar height is clamped to ≤ 12% of nearest container height

# text-bearing classes; extend if needed
const FONT_CLASSES: Array[StringName] = [
    StringName("Label"), StringName("Button"), StringName("CheckBox"),
    StringName("LineEdit"), StringName("TextEdit"), StringName("OptionButton"),
    StringName("MenuButton"), StringName("SpinBox"), StringName("ItemList"),
    StringName("Tree"), StringName("Tabs"), StringName("TabBar")
]

# ---------- state ----------
var theme_local: Theme
var base_font_size: Dictionary = {}     # {class_name -> int}
var base_default_font: int = 0
var bar_base_h: Dictionary = {}         # {id(int) -> float}  baseline thickness per bar

# ---------- lifecycle ----------
func _ready() -> void:
    var project_theme: Theme = ThemeDB.get_project_theme()
    assert(project_theme != null)
    theme_local = project_theme.duplicate()
    theme = theme_local

    _cache_font_baselines()
    _cache_existing_bars()
    _apply()

    get_viewport().connect("size_changed", Callable(self, "_apply"))
    get_tree().connect("node_added", Callable(self, "_on_node_added"))

func _on_node_added(n: Node) -> void:
    if not is_ancestor_of(n): return
    if n is ProgressBar or n is TextureProgressBar:
        n.connect("tree_entered", Callable(self, "_on_bar_entered").bind(n.get_instance_id()), Object.CONNECT_ONE_SHOT)
        n.connect("tree_exiting", Callable(self, "_on_bar_exiting").bind(n.get_instance_id()))
    else:
        call_deferred("_rescan_subtree", n.get_instance_id())

func _on_bar_entered(id: int) -> void:
    var obj: Object = instance_from_id(id)
    assert(obj is Control)
    _cache_one_bar(obj as Control)
    _apply()

func _on_bar_exiting(id: int) -> void:
    bar_base_h.erase(id)

func _rescan_subtree(id: int) -> void:
    var obj: Object = instance_from_id(id)
    assert(obj is Node)
    _for_each_bar(obj as Node, func(b: Control) -> void: _cache_one_bar(b))
    _apply()

func rescan() -> void:
    _cache_existing_bars()
    _apply()

# ---------- baselines ----------
func _cache_font_baselines() -> void:
    base_font_size.clear()
    for cls in FONT_CLASSES:
        base_font_size[cls] = theme_local.get_font_size(StringName("font_size"), cls)
    base_default_font = theme_local.default_font_size

func _cache_existing_bars() -> void:
    bar_base_h.clear()
    _for_each_bar(self, func(b: Control) -> void: _cache_one_bar(b))

func _cache_one_bar(b: Control) -> void:
    assert(b.is_inside_tree())
    var id: int = b.get_instance_id()
    # Authoring baseline = real minimum including stylebox floors
    var h: float = b.get_combined_minimum_size().y
    if h <= 0.0: h = 1.0
    bar_base_h[id] = h

# ---------- apply ----------
func _apply() -> void:
    # physical driver (CSS×DPR) — zoom-proof
    var win: Vector2i = get_window().size
    var dpr: float = DisplayServer.screen_get_scale()
    var k_css: float = min(float(win.x) / float(BASE_SIZE.x), float(win.y) / float(BASE_SIZE.y))
    var k_phys: float = k_css * dpr

    # perceived UI scale
    var a_ui: float = log(AT_2X) / log(2.0)
    var p_ui: float = pow(k_phys, a_ui)

    # layout through theme
    theme_local.default_base_scale = p_ui / (k_css * dpr)

    # fonts (fonts ignore default_base_scale)
    var s_font: float = p_ui / dpr
    for cls in FONT_CLASSES:
        var fs: int = int(round(float(base_font_size[cls]) * s_font))
        theme_local.set_font_size(StringName("font_size"), cls, max(1, fs))
    theme_local.default_font_size = max(1, int(round(float(base_default_font) * s_font)))

    # bars: independent slope + gain + hard cap; strip vertical EXPAND unconditionally
    var a_bar: float = log(BAR_AT_2X) / log(2.0)
    var p_bar: float = pow(k_phys, a_bar) * BAR_GAIN

    for id in bar_base_h.keys():
        var obj: Object = instance_from_id(id); assert(obj is Control)
        var c: Control = obj as Control

        var h_target: float = float(bar_base_h[id]) * p_bar
        var cap: float = _nearest_container_height(c) * BAR_MAX_FRAC
        if h_target > cap: h_target = cap

        # if it's a ProgressBar (not TextureProgressBar), clamp vertical floors of its styleboxes
        if c is ProgressBar:
            _clamp_bar_styleboxes(c as ProgressBar, h_target)

# ---------- helpers ----------
func _nearest_container_height(c: Control) -> float:
    var n: Node = c.get_parent()
    while n != null:
        if n is VBoxContainer or n is PanelContainer or n is HSplitContainer or n is VSplitContainer:
            return (n as Control).size.y
        n = n.get_parent()
    return float(get_window().size.y)

func _clamp_bar_styleboxes(pb: ProgressBar, h_target: float) -> void:
    var sbg0: StyleBox = pb.get_theme_stylebox(StringName("background"))
    var sbf0: StyleBox = pb.get_theme_stylebox(StringName("fill"))
    var sbg: StyleBox = sbg0.duplicate()
    var sbf: StyleBox = sbf0.duplicate()

    var bg_v: float = sbg.content_margin_top + sbg.content_margin_bottom
    var fi_v: float = sbf.content_margin_top + sbf.content_margin_bottom

    if bg_v > h_target:
        var t: float = h_target / bg_v
        sbg.content_margin_top *= t
        sbg.content_margin_bottom *= t
    if fi_v > h_target:
        var u: float = h_target / fi_v
        sbf.content_margin_top *= u
        sbf.content_margin_bottom *= u

    pb.add_theme_stylebox_override(StringName("background"), sbg)
    pb.add_theme_stylebox_override(StringName("fill"), sbf)

func _for_each_bar(root: Node, f: Callable) -> void:
    for c in root.get_children():
        if c is ProgressBar or c is TextureProgressBar:
            f.call(c)
        _for_each_bar(c, f)
