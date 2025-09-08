# PopText.gd — jitter-free: move vertices in a canvas_item shader, not the Control.
# Fonts still scale once from UIRoot.s_percept.

class_name PopText
extends Label

var target: Node3D
var lastPos: Vector3
var hasPos: bool = false

@export var baseOffsetPx: float = -40.0        # static bias in UI px
@export var risePx: float = -30.0             # total rise in px (negative = up on screen)
@export var durationS: float = 2.0

var animMat: ShaderMaterial
var font0: int = 0
var outline0: int = 0

func _ready() -> void:
    assert(label_settings != null)
    assert(label_settings.resource_local_to_scene)

    font0 = label_settings.font_size
    outline0 = label_settings.outline_size
    var ui: UIRoot = get_tree().get_first_node_in_group("ui_root") as UIRoot
    assert(ui != null)
    var s: float = ui.s_percept
    label_settings.font_size = max(1, int(round(float(font0) * s)))
    label_settings.outline_size = max(0, int(round(float(outline0) * s)))

    # shader: offset vertices in screen-space Y with sub-pixel precision
    var sh: Shader = Shader.new()
    sh.code = """
        shader_type canvas_item;
        uniform float y_off_px = 0.0;
        void vertex() {
            VERTEX.y += y_off_px;
        }
    """
    animMat = ShaderMaterial.new()
    animMat.shader = sh
    material = animMat

    process_mode = Node.PROCESS_MODE_ALWAYS

func pop_damage(t: Node3D, txt: String, hp_frac: float) -> void:
    target = t; text = txt; modulate = Color(1.0 - hp_frac, hp_frac, 0.0); z_index = 0
    _rise()

func pop_xp(t: Node3D, txt: String) -> void:
    target = t; text = txt; modulate = Color.GREEN; z_index = 500
    _rise()

func pop_levelup(t: Node3D) -> void:
    target = t; text = "LEVEL UP"; modulate = Color.GREEN; z_index = 1000
    _rise()

func _rise() -> void:
    animMat.set_shader_parameter("y_off_px", 0.0)
    var tw: Tween = create_tween()
    tw.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
    tw.set_ignore_time_scale(true)
    tw.tween_property(animMat, "shader_parameter/y_off_px", risePx, durationS).set_ease(Tween.EASE_OUT)
    tw.parallel().tween_property(self, "modulate:a", 0.0, durationS * 0.5)
    tw.finished.connect(queue_free)

func _process(_dt: float) -> void:
    var cam: Camera3D = get_viewport().get_camera_3d()
    assert(cam != null)

    if target and target.is_inside_tree():
        lastPos = target.global_position
        hasPos = true
    if not hasPos:
        queue_free()
        return

    var sp: Vector2 = cam.unproject_position(lastPos)
    position = sp + Vector2(-size.x * 0.5, baseOffsetPx)
