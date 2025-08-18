extends Node3D
class_name Sprite3DHelper

@export var sprite: SpriteBase3D
var waste_cut: bool = false

const WAIST_CUT_SHADER = preload("res://Scenes/Player/cutwaist3d.gdshader")
var waist_cut_shader_material := ShaderMaterial.new()

func _ready():
    waist_cut_shader_material.shader = WAIST_CUT_SHADER
    sprite.material_override = null
    _bind_tex()

func _process(_delta):
    sprite.material_override = waist_cut_shader_material if waste_cut else null
    var cam = get_viewport().get_camera_3d()
    var screen_pos = cam.unproject_position(global_transform.origin)
    var y = clamp(screen_pos.y / get_viewport().size.y, 0.0, 1.0)
    sprite.render_priority = int(lerp(RenderingServer.MATERIAL_RENDER_PRIORITY_MIN, RenderingServer.MATERIAL_RENDER_PRIORITY_MAX, y))

func _bind_tex():
    waist_cut_shader_material.set_shader_parameter("sprite_tex",
        sprite.texture if sprite is Sprite3D
        else sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame))
