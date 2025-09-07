# UIRoot.gd — one owner, one scale. Web == Editor. Late UI safe.
extends Control

const BASE_SIZE: Vector2i = Vector2i(1152, 648)    # design resolution
const AT_2X: float = 0.90                          # k_phys doubles -> perceived scale multiplies by this (<1 shrinks)

const FONT_CLASSES: Array[StringName] = [
    StringName("Label"), StringName("Button"), StringName("CheckBox"),
    StringName("LineEdit"), StringName("TextEdit"), StringName("OptionButton"),
    StringName("MenuButton"), StringName("SpinBox"), StringName("ItemList"),
    StringName("Tree"), StringName("Tabs"), StringName("TabBar")
]

var theme_local: Theme
var base_font_size: Dictionary = {}
var base_default_font: int = 0

# Per-node baselines keyed by instance_id
var bar_base_h: Dictionary = {}         # {id -> float}
var pb_bg_m: Dictionary = {}            # {id -> {"l","r","t","b" -> float}}
var pb_fill_m: Dictionary = {}          # {id -> {"l","r","t","b" -> float}}

# Class baselines (used when node has no overrides)
var class_bg_m: Dictionary = {}         # {"l","r","t","b" -> float}
var class_fill_m: Dictionary = {}       # {"l","r","t","b" -> float}

func _ready() -> void:
    var project_theme: Theme = ThemeDB.get_project_theme()
    assert(project_theme != null)
    theme_local = project_theme.duplicate()
    theme = theme_local

    _cache_font_baselines()
    _cache_class_styleboxes()
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
    var obj: Object = instance_from_id(id); assert(obj is Control)
    _cache_one_bar(obj as Control); _apply()

func _on_bar_exiting(id: int) -> void:
    bar_base_h.erase(id); pb_bg_m.erase(id); pb_fill_m.erase(id)

func _rescan_subtree(id: int) -> void:
    var obj: Object = instance_from_id(id); assert(obj is Node)
    _for_each_bar(obj as Node, func(b: Control) -> void: _cache_one_bar(b))
    _apply()

func rescan() -> void:
    _cache_existing_bars(); _apply()

# ---------- Baselines ----------

func _cache_font_baselines() -> void:
    base_font_size.clear()
    for cls in FONT_CLASSES: base_font_size[cls] = theme_local.get_font_size(StringName("font_size"), cls)
    base_default_font = theme_local.default_font_size

func _cache_class_styleboxes() -> void:
    class_bg_m.clear(); class_fill_m.clear()
    var sb_bg: StyleBox = theme_local.get_stylebox(StringName("background"), StringName("ProgressBar"))
    var sb_fill: StyleBox = theme_local.get_stylebox(StringName("fill"), StringName("ProgressBar"))
    assert(sb_bg != null and sb_fill != null)
    class_bg_m["l"] = sb_bg.content_margin_left;  class_bg_m["r"] = sb_bg.content_margin_right
    class_bg_m["t"] = sb_bg.content_margin_top;   class_bg_m["b"] = sb_bg.content_margin_bottom
    class_fill_m["l"] = sb_fill.content_margin_left; class_fill_m["r"] = sb_fill.content_margin_right
    class_fill_m["t"] = sb_fill.content_margin_top;  class_fill_m["b"] = sb_fill.content_margin_bottom

func _cache_existing_bars() -> void:
    bar_base_h.clear(); pb_bg_m.clear(); pb_fill_m.clear()
    _for_each_bar(self, func(b: Control) -> void: _cache_one_bar(b))

func _cache_one_bar(b: Control) -> void:
    assert(b.is_inside_tree())
    var id: int = b.get_instance_id()
    var h: float = b.get_combined_minimum_size().y
    if h <= 0.0: h = 1.0
    bar_base_h[id] = h

    if b is ProgressBar:
        var pb: ProgressBar = b as ProgressBar
        if pb.has_theme_stylebox_override(StringName("background")):
            var sb_bg: StyleBox = pb.get_theme_stylebox(StringName("background"))
            pb_bg_m[id] = {"l": sb_bg.content_margin_left, "r": sb_bg.content_margin_right, "t": sb_bg.content_margin_top, "b": sb_bg.content_margin_bottom}
        if pb.has_theme_stylebox_override(StringName("fill")):
            var sb_fill: StyleBox = pb.get_theme_stylebox(StringName("fill"))
            pb_fill_m[id] = {"l": sb_fill.content_margin_left, "r": sb_fill.content_margin_right, "t": sb_fill.content_margin_top, "b": sb_fill.content_margin_bottom}

# ---------- Apply ----------

func _apply() -> void:
    # Physical driver (CSS×DPR) so browser zoom doesn’t distort the curve
    var win: Vector2i = get_window().size
    var dpr: float = DisplayServer.screen_get_scale()
    var k_css: float = min(float(win.x) / float(BASE_SIZE.x), float(win.y) / float(BASE_SIZE.y))
    var k_phys: float = k_css * dpr

    # Perceived target p with s(2) = AT_2X
    var a: float = log(AT_2X) / log(2.0)
    var p: float = pow(k_phys, a)

    # Layout: enforce k_css * dpr * b == p
    theme_local.default_base_scale = p / (k_css * dpr)

    # Fonts: explicit (fonts ignore default_base_scale)
    var s_font: float = p / dpr
    for cls in FONT_CLASSES:
        var fs: int = int(round(float(base_font_size[cls]) * s_font))
        theme_local.set_font_size(StringName("font_size"), cls, max(1, fs))
    theme_local.default_font_size = max(1, int(round(float(base_default_font) * s_font)))

    # Bars: set target height and clamp background/fill vertical floors so they cannot exceed it
    for id in bar_base_h.keys():
        var obj: Object = instance_from_id(id); assert(obj is Control)
        var c: Control = obj as Control
        var h_target: float = float(bar_base_h[id]) * p
        c.custom_minimum_size = Vector2(c.custom_minimum_size.x, h_target)

        if c is ProgressBar:
            var pb: ProgressBar = c as ProgressBar
            # choose baselines: node override if present, else class baseline
            var bg_src: Dictionary = pb_bg_m[id] if pb_bg_m.has(id) else class_bg_m
            var fill_src: Dictionary = pb_fill_m[id] if pb_fill_m.has(id) else class_fill_m

            # scale intended margins by p
            var bg_t: float = float(bg_src["t"]) * p
            var bg_b: float = float(bg_src["b"]) * p
            var fi_t: float = float(fill_src["t"]) * p
            var fi_b: float = float(fill_src["b"]) * p

            # clamp vertical floors so stylebox minimums never exceed target height
            var max_bg_v: float = h_target * 0.6   # background gets at most 60% of height as vertical padding
            var max_fi_v: float = h_target * 0.6   # fill likewise; tune if you want
            var scale_bg: float = min(1.0, max_bg_v / max(1.0, bg_t + bg_b))
            var scale_fi: float = min(1.0, max_fi_v / max(1.0, fi_t + fi_b))

            var sbg0: StyleBox = pb.get_theme_stylebox(StringName("background"))
            var sbf0: StyleBox = pb.get_theme_stylebox(StringName("fill"))
            var sbg: StyleBox = sbg0.duplicate()
            var sbf: StyleBox = sbf0.duplicate()

            sbg.content_margin_top = bg_t * scale_bg
            sbg.content_margin_bottom = bg_b * scale_bg
            sbf.content_margin_top = fi_t * scale_fi
            sbf.content_margin_bottom = fi_b * scale_fi

            pb.add_theme_stylebox_override(StringName("background"), sbg)
            pb.add_theme_stylebox_override(StringName("fill"), sbf)

# ---------- Helpers ----------

func _for_each_bar(root: Node, f: Callable) -> void:
    for c in root.get_children():
        if c is ProgressBar or c is TextureProgressBar:
            f.call(c)
        _for_each_bar(c, f)
