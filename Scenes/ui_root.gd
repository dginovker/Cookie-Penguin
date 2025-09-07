# UIRoot.gd — one owner, one scale. Web == Editor. Late UI safe.
extends Control

const BASE_SIZE: Vector2i = Vector2i(1152, 648) # design resolution
const AT_2X: float = 0.90                       # when physical UI scale doubles, multiply fonts/margins by this (<1 shrinks)

const FONT_CLASSES: Array[StringName] = [
    StringName("Label"), StringName("Button"), StringName("CheckBox"),
    StringName("LineEdit"), StringName("TextEdit"), StringName("OptionButton"),
    StringName("MenuButton"), StringName("SpinBox"), StringName("ItemList"),
    StringName("Tree"), StringName("Tabs"), StringName("TabBar")
]

var themeLocal: Theme
var baseFontSize: Dictionary = {}      # {class_name -> int}
var baseDefaultFont: int = 0

# ProgressBar CLASS stylebox baselines (content margins)
var pbClassBg: Dictionary = {}         # {"l"|"r"|"t"|"b" -> float}
var pbClassFill: Dictionary = {}

# Per-node baselines keyed by instance_id (ints)
var pbNodeBg: Dictionary = {}          # {id -> {"l"|"r"|"t"|"b" -> float}}
var pbNodeFill: Dictionary = {}        # {id -> {...}}
var tpbNodeH: Dictionary = {}          # {id -> float}  # TextureProgressBar baseline height

func _ready() -> void:
    var projectTheme: Theme = ThemeDB.get_project_theme()
    assert(projectTheme != null)
    themeLocal = projectTheme.duplicate()
    theme = themeLocal

    _cache_baselines_class()
    _cache_existing_nodes()
    _apply()

    get_viewport().connect("size_changed", Callable(self, "_apply"))
    get_tree().connect("node_added", Callable(self, "_on_node_added"))

func _on_node_added(n: Node) -> void:
    if not is_ancestor_of(n): return
    if n is ProgressBar or n is TextureProgressBar:
        # Register after it actually enters the tree; no null checks
        n.connect("tree_entered", Callable(self, "_on_bar_entered").bind(n.get_instance_id()), Object.CONNECT_ONE_SHOT)
        n.connect("tree_exiting", Callable(self, "_on_bar_exiting").bind(n.get_instance_id()))
    else:
        # If a big subtree is added, rescan next frame when children are inside_tree
        call_deferred("_rescan_subtree", n.get_instance_id())

func _on_bar_entered(id: int) -> void:
    var obj: Object = instance_from_id(id)
    assert(obj is Control)
    _cache_one_node(obj as Control)
    _apply()

func _on_bar_exiting(id: int) -> void:
    pbNodeBg.erase(id); pbNodeFill.erase(id); tpbNodeH.erase(id)

func _rescan_subtree(id: int) -> void:
    var obj: Object = instance_from_id(id)
    assert(obj is Node)
    _for_each_bar(obj as Node, func(b: Control) -> void: _cache_one_node(b))
    _apply()

# Call manually if you bulk-add UI and want to force a pass
func rescan() -> void:
    _cache_existing_nodes()
    _apply()

# ---------- Baselines ----------

func _cache_baselines_class() -> void:
    baseFontSize.clear()
    for cls in FONT_CLASSES: baseFontSize[cls] = themeLocal.get_font_size(StringName("font_size"), cls)
    baseDefaultFont = themeLocal.default_font_size

    pbClassBg.clear(); pbClassFill.clear()
    var sbBg: StyleBox = themeLocal.get_stylebox(StringName("background"), StringName("ProgressBar"))
    var sbFill: StyleBox = themeLocal.get_stylebox(StringName("fill"), StringName("ProgressBar"))
    assert(sbBg != null and sbFill != null)
    pbClassBg["l"] = sbBg.content_margin_left;  pbClassBg["r"] = sbBg.content_margin_right
    pbClassBg["t"] = sbBg.content_margin_top;   pbClassBg["b"] = sbBg.content_margin_bottom
    pbClassFill["l"] = sbFill.content_margin_left;  pbClassFill["r"] = sbFill.content_margin_right
    pbClassFill["t"] = sbFill.content_margin_top;   pbClassFill["b"] = sbFill.content_margin_bottom

func _cache_existing_nodes() -> void:
    pbNodeBg.clear(); pbNodeFill.clear(); tpbNodeH.clear()
    _for_each_bar(self, func(b: Control) -> void: _cache_one_node(b))

func _cache_one_node(b: Control) -> void:
    assert(b.is_inside_tree())
    var id: int = b.get_instance_id()
    if b is ProgressBar:
        var pb: ProgressBar = b as ProgressBar
        if pb.has_theme_stylebox_override(StringName("background")):
            var sb1: StyleBox = pb.get_theme_stylebox(StringName("background"))
            pbNodeBg[id] = {"l": sb1.content_margin_left, "r": sb1.content_margin_right, "t": sb1.content_margin_top, "b": sb1.content_margin_bottom}
        if pb.has_theme_stylebox_override(StringName("fill")):
            var sb2: StyleBox = pb.get_theme_stylebox(StringName("fill"))
            pbNodeFill[id] = {"l": sb2.content_margin_left, "r": sb2.content_margin_right, "t": sb2.content_margin_top, "b": sb2.content_margin_bottom}
    elif b is TextureProgressBar:
        var tb: TextureProgressBar = b as TextureProgressBar
        var h: float = tb.size.y
        if h <= 0.0: h = tb.get_combined_minimum_size().y
        assert(h > 0.0)
        tpbNodeH[id] = h

# ---------- Apply ----------

func _apply() -> void:
    # Physical driver (CSS×DPR) so browser zoom doesn’t distort the curve
    var win: Vector2i = get_window().size
    var dpr: float = DisplayServer.screen_get_scale()
    var kCss: float = min(float(win.x) / float(BASE_SIZE.x), float(win.y) / float(BASE_SIZE.y))
    var kPhys: float = kCss * dpr

    # Perceived target p, with s(2) = AT_2X
    var a: float = log(AT_2X) / log(2.0)
    var p: float = pow(kPhys, a)

    # Layout (styleboxes/constants): enforce kCss * dpr * b == p
    themeLocal.default_base_scale = p / (kCss * dpr)

    # Fonts: they ignore default_base_scale; scale explicitly and cancel DPR
    var sFont: float = p / dpr
    for cls in FONT_CLASSES:
        var fs: int = int(round(float(baseFontSize[cls]) * sFont))
        themeLocal.set_font_size(StringName("font_size"), cls, max(1, fs))
    themeLocal.default_font_size = max(1, int(round(float(baseDefaultFont) * sFont)))

    # ProgressBar CLASS styleboxes — bars without node overrides follow these
    _scale_pb_class_margins(p)

    # Node-level overrides — bars that opted out follow their own cached baselines
    for id in pbNodeBg.keys():
        var obj1: Object = instance_from_id(id); assert(obj1 is ProgressBar)
        var pb1: ProgressBar = obj1 as ProgressBar
        var d1: Dictionary = pbNodeBg[id]
        var sb1_0: StyleBox = pb1.get_theme_stylebox(StringName("background"))
        var sb1: StyleBox = sb1_0.duplicate()
        sb1.content_margin_left   = float(d1["l"]) * p
        sb1.content_margin_right  = float(d1["r"]) * p
        sb1.content_margin_top    = float(d1["t"]) * p
        sb1.content_margin_bottom = float(d1["b"]) * p
        pb1.add_theme_stylebox_override(StringName("background"), sb1)

    for id in pbNodeFill.keys():
        var obj2: Object = instance_from_id(id); assert(obj2 is ProgressBar)
        var pb2: ProgressBar = obj2 as ProgressBar
        var d2: Dictionary = pbNodeFill[id]
        var sb2_0: StyleBox = pb2.get_theme_stylebox(StringName("fill"))
        var sb2: StyleBox = sb2_0.duplicate()
        sb2.content_margin_left   = float(d2["l"]) * p
        sb2.content_margin_right  = float(d2["r"]) * p
        sb2.content_margin_top    = float(d2["t"]) * p
        sb2.content_margin_bottom = float(d2["b"]) * p
        pb2.add_theme_stylebox_override(StringName("fill"), sb2)

    # TextureProgressBar — force thickness via custom_minimum_size.y from baseline (zoom-proof)
    for id in tpbNodeH.keys():
        var obj3: Object = instance_from_id(id); assert(obj3 is TextureProgressBar)
        var tb: TextureProgressBar = obj3 as TextureProgressBar
        tb.custom_minimum_size = Vector2(tb.custom_minimum_size.x, float(tpbNodeH[id]) * p)

# ---------- Helpers ----------

func _scale_pb_class_margins(p: float) -> void:
    var bg0: StyleBox = themeLocal.get_stylebox(StringName("background"), StringName("ProgressBar"))
    var fill0: StyleBox = themeLocal.get_stylebox(StringName("fill"), StringName("ProgressBar"))
    assert(bg0 != null and fill0 != null)
    var bg: StyleBox = bg0.duplicate()
    var fill: StyleBox = fill0.duplicate()
    bg.content_margin_left   = float(pbClassBg["l"]) * p
    bg.content_margin_right  = float(pbClassBg["r"]) * p
    bg.content_margin_top    = float(pbClassBg["t"]) * p
    bg.content_margin_bottom = float(pbClassBg["b"]) * p
    fill.content_margin_left   = float(pbClassFill["l"]) * p
    fill.content_margin_right  = float(pbClassFill["r"]) * p
    fill.content_margin_top    = float(pbClassFill["t"]) * p
    fill.content_margin_bottom = float(pbClassFill["b"]) * p
    themeLocal.set_stylebox(StringName("background"), StringName("ProgressBar"), bg)
    themeLocal.set_stylebox(StringName("fill"), StringName("ProgressBar"), fill)

func _for_each_bar(root: Node, f: Callable) -> void:
    for c in root.get_children():
        if c is ProgressBar or c is TextureProgressBar:
            f.call(c)
        _for_each_bar(c, f)
