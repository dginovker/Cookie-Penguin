class_name VirtualJoystick
extends Control

## A simple virtual joystick for touchscreens, with useful options.
## Github: https://github.com/MarcoFazioRandom/Virtual-Joystick-Godot

# EXPORTED VARIABLES

## The color of the button when the joystick is pressed.
@export var pressed_color := Color.GRAY

## Deadzone and clamp as ratios of Base size (resolution independent)
@export_range(0.0, 0.5, 0.01) var deadzone_ratio : float = 0.1
@export_range(0.0, 1.0, 0.01) var clampzone_ratio : float = 0.5

enum JoystickMode { FIXED, DYNAMIC, FOLLOWING }
@export var joystick_mode : JoystickMode = JoystickMode.FIXED

enum VisibilityMode { ALWAYS, TOUCHSCREEN_ONLY, WHEN_TOUCHED }
@export var visibility_mode : VisibilityMode = VisibilityMode.ALWAYS

@export var use_input_actions := true
@export var action_left := "ui_left"
@export var action_right := "ui_right"
@export var action_up := "ui_up"
@export var action_down := "ui_down"

# PUBLIC VARIABLES
var is_pressed := false
var output := Vector2.ZERO

# PRIVATE VARIABLES
var _touch_index : int = -1
@onready var _base : Control = $Base
@onready var _tip  : Control = $Base/Tip
@onready var _base_default_position : Vector2 = Vector2.ZERO
@onready var _tip_default_position  : Vector2 = Vector2.ZERO
@onready var _default_color : Color = Color.WHITE

# LIFECYCLE
func _ready() -> void:
    if ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch"):
        printerr("The Project Setting 'emulate_mouse_from_touch' should be set to False")
    if not ProjectSettings.get_setting("input_devices/pointing/emulate_touch_from_mouse"):
        printerr("The Project Setting 'emulate_touch_from_mouse' should be set to True")

    if not DisplayServer.is_touchscreen_available() and visibility_mode == VisibilityMode.TOUCHSCREEN_ONLY:
        hide()
    if visibility_mode == VisibilityMode.WHEN_TOUCHED:
        hide()

    _default_color = _tip.modulate
    get_viewport().size_changed.connect(_layout)
    _layout()

func _layout() -> void:
    await get_tree().process_frame
    await get_tree().process_frame
    _base.pivot_offset = _base.size * 0.5
    _tip.pivot_offset  = _tip.size  * 0.5
    _base_default_position = _base.position
    _tip_default_position  = _tip.position
    _reset()

# INPUT
func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        var st := event as InputEventScreenTouch
        if st.pressed:
            if _is_point_inside_joystick_area(st.position) and _touch_index == -1:
                var can_start := joystick_mode == JoystickMode.DYNAMIC \
                    or joystick_mode == JoystickMode.FOLLOWING \
                    or (joystick_mode == JoystickMode.FIXED and _is_point_inside_base(st.position))
                if can_start:
                    if joystick_mode != JoystickMode.FIXED:
                        _move_base(st.position)
                    if visibility_mode == VisibilityMode.WHEN_TOUCHED:
                        show()
                    _touch_index = st.index
                    _tip.modulate = pressed_color
                    _update_joystick(st.position)
                    get_viewport().set_input_as_handled()
        elif st.index == _touch_index:
            _reset()
            if visibility_mode == VisibilityMode.WHEN_TOUCHED:
                hide()
            get_viewport().set_input_as_handled()
    elif event is InputEventScreenDrag:
        var sd := event as InputEventScreenDrag
        if sd.index == _touch_index:
            _update_joystick(sd.position)
            get_viewport().set_input_as_handled()

# HELPERS
func _screen_to_local(ctrl: Control, p_screen: Vector2) -> Vector2:
    return ctrl.get_global_transform_with_canvas().affine_inverse() * p_screen

func _dir_local_to_screen(ctrl: Control, v_local: Vector2) -> Vector2:
    var xf := ctrl.get_global_transform_with_canvas()
    return (xf * v_local) - xf.origin

func _move_base(touch_screen: Vector2) -> void:
    var parent := _base.get_parent() as Control
    var parent_local := _screen_to_local(parent, touch_screen)
    _base.position = parent_local - _base.pivot_offset

func _move_tip(touch_screen: Vector2) -> void:
    var base_local := _screen_to_local(_base, touch_screen)
    _tip.position = base_local - _tip.pivot_offset

func _is_point_inside_joystick_area(p_screen: Vector2) -> bool:
    return get_global_rect().has_point(p_screen)

func _is_point_inside_base(p_screen: Vector2) -> bool:
    var p_local := _screen_to_local(_base, p_screen)
    var center  := _base.pivot_offset
    var r := _base.size.x * 0.5
    return p_local.distance_squared_to(center) <= r * r

# MAIN JOYSTICK LOGIC
func _update_joystick(touch_screen: Vector2) -> void:
    var touch_local := _screen_to_local(_base, touch_screen)
    var center := _base.pivot_offset
    var delta := touch_local - center
    var dist := delta.length()

    var clampzone_size := (_base.size.x * 0.5) * clampzone_ratio
    var v = (delta * min(1.0, clampzone_size / dist)) if dist > 0.0 else Vector2.ZERO

    if joystick_mode == JoystickMode.FOLLOWING and dist > clampzone_size:
        _move_base(touch_screen - _dir_local_to_screen(_base, v))
        touch_local = _screen_to_local(_base, touch_screen)
        center = _base.pivot_offset
        delta = touch_local - center
        dist = delta.length()
        v = (delta * min(1.0, clampzone_size / dist)) if dist > 0.0 else Vector2.ZERO

    _tip.position = (center + v) - _tip.pivot_offset

    var dz := clampzone_size * deadzone_ratio
    if v.length_squared() > dz * dz:
        is_pressed = true
        output = (v - v.normalized() * dz) / (clampzone_size - dz)
    else:
        is_pressed = false
        output = Vector2.ZERO

    if use_input_actions:
        if output.x >= 0.0 and Input.is_action_pressed(action_left):  Input.action_release(action_left)
        if output.x <= 0.0 and Input.is_action_pressed(action_right): Input.action_release(action_right)
        if output.y >= 0.0 and Input.is_action_pressed(action_up):    Input.action_release(action_up)
        if output.y <= 0.0 and Input.is_action_pressed(action_down):  Input.action_release(action_down)
        if output.x < 0.0: Input.action_press(action_left,  -output.x)
        if output.x > 0.0: Input.action_press(action_right,  output.x)
        if output.y < 0.0: Input.action_press(action_up,     -output.y)
        if output.y > 0.0: Input.action_press(action_down,    output.y)

func _reset() -> void:
    is_pressed = false
    output = Vector2.ZERO
    _touch_index = -1
    _tip.modulate = _default_color
    _base.position = _base_default_position
    _tip.position  = _tip_default_position
    if use_input_actions:
        for action in [action_left, action_right, action_down, action_up]:
            if Input.is_action_pressed(action):
                Input.action_release(action)
