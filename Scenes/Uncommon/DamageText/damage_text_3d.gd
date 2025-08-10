extends Node3D
@onready var m: MeshInstance3D = $Mesh

func _ready():
    (m.mesh as TextMesh).font_size = 120   # make it readable

func _process(_dt):
    Yeet.billboard_me(self)                # Z-fixed billboard

func pop(amount:int, percent_left:float, life:=1.0, rise:=1.0) -> void:
    (m.mesh as TextMesh).text = "-" + str(amount)

    var mat := (m.material_override as ShaderMaterial).duplicate()
    mat.resource_local_to_scene = true
    m.material_override = mat

    var now := float(Time.get_ticks_msec())/1000.0
    mat.set_shader_parameter("start_time", now)
    mat.set_shader_parameter("life", life)
    mat.set_shader_parameter("rise", rise)
    mat.set_shader_parameter("hp_left", clamp(percent_left, 0.0, 1.0))

    translate((get_viewport().get_camera_3d().global_position - global_position).normalized() * 0.04)
    await get_tree().create_timer(life).timeout
    queue_free()
