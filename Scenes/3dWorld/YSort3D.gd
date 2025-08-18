extends Node3D

@export var sprite: SpriteBase3D
const SHADER = preload("res://Scenes/Player/cutwaist3d.gdshader")
var sm := ShaderMaterial.new()

func _ready():
    sm.shader = SHADER
    sprite.material_override = sm
    _bind_tex()

func _process(_delta):
    if sprite is AnimatedSprite3D:
        _bind_tex()

    var cam = get_viewport().get_camera_3d()
    var screen_pos = cam.unproject_position(global_transform.origin)
    var y = clamp(screen_pos.y / get_viewport().size.y, 0.0, 1.0)
    sprite.render_priority = int(lerp(RenderingServer.MATERIAL_RENDER_PRIORITY_MIN, RenderingServer.MATERIAL_RENDER_PRIORITY_MAX, y))

func _bind_tex():
    sm.set_shader_parameter("sprite_tex",
        sprite.texture if sprite is Sprite3D
        else sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame))
