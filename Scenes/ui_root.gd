# UIRoot.gd — single owner, single scale. Web == Editor. Late UI safe.
# Fonts + layout via theme. No bar code. No separation overrides.
# Goal: behave as if HiDPI were OFF for perceived size, while keeping HiDPI raster fidelity.

extends Control

# ---------- knobs ----------
const BASE_SIZE: Vector2i = Vector2i(1152, 648)   # design resolution (CSS px)
const AT_2X: float = 1.00                         # perceived UI slope; 1.0 = proportional

# text-bearing classes; extend if needed
const FONT_CLASSES: Array[StringName] = [
    StringName("Label"), StringName("Button"), StringName("CheckBox"),
    StringName("LineEdit"), StringName("TextEdit"), StringName("OptionButton"),
    StringName("MenuButton"), StringName("SpinBox"), StringName("ItemList"),
    StringName("Tree"), StringName("Tabs"), StringName("TabBar")
]

# ---------- state ----------
var theme_local: Theme
var base_font_size: Dictionary[StringName, int] = {}
var base_default_font: int = 0

# ---------- lifecycle ----------
func _ready() -> void:
    var project_theme: Theme = ThemeDB.get_project_theme()
    assert(project_theme != null)
    theme_local = project_theme.duplicate()
    theme = theme_local

    _cache_font_baselines()
    _apply()

    get_viewport().connect("size_changed", Callable(self, "_apply"))
    get_window().connect("dpi_changed", Callable(self, "_apply"))

# ---------- baselines ----------
func _cache_font_baselines() -> void:
    base_font_size.clear()
    for cls in FONT_CLASSES:
        base_font_size[cls] = theme_local.get_font_size(StringName("font_size"), cls)
    base_default_font = theme_local.default_font_size

# ---------- apply ----------
func _apply() -> void:
    # CSS-space driver (no DPR). canvas_items+Expand -> visible rect == CSS size
    var css: Vector2 = get_viewport().get_visible_rect().size
    var s_css: float = min(css.x / float(BASE_SIZE.x), css.y / float(BASE_SIZE.y))

    # perceived UI scale (slope knob)
    var a_ui: float = log(AT_2X) / log(2.0)
    var s_ui: float = pow(s_css, a_ui)

    # neutralize HiDPI for perception; DPR only improves raster fidelity
    var dpr: float = DisplayServer.screen_get_scale()
    var s_percept: float = s_ui / dpr

    # layout through theme (paddings, styleboxes, container math)
    theme_local.default_base_scale = s_percept

    # fonts (fonts ignore default_base_scale) — keep DPR-neutral
    for cls in FONT_CLASSES:
        var fs: int = int(round(float(base_font_size[cls]) * s_percept))
        theme_local.set_font_size(StringName("font_size"), cls, max(1, fs))
    theme_local.default_font_size = max(1, int(round(float(base_default_font) * s_percept)))
