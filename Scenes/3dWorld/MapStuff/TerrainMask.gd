# TerrainMask.gd
class_name TerrainMask
extends Resource

@export var ppm:float
@export var origin := Vector2.ZERO
@export var mask0:Texture2D
@export var mask1:Texture2D
@export var mask2:Texture2D
@export var layer_names := PackedStringArray()

func _img(t:Texture2D)->Image: return t.get_image()
func _px(u:Vector2)->Vector2i:
    var p = (u - origin) * ppm
    return Vector2i(int(p.x), int(p.y))

func weights_at(xz:Vector2)->PackedFloat32Array:
    var i0=_img(mask0); var i1=_img(mask1); var i2=_img(mask2)
    var p=_px(xz)
    var a=i0.get_pixelv(p); var b=i1.get_pixelv(p); var c=i2.get_pixelv(p)
    return PackedFloat32Array([a.r,a.g,a.b,b.r,b.g,b.b,c.r,c.g,c.b])

func max_index_at(xz:Vector2)->int:
    var w=weights_at(xz)
    var idx=0; var best=w[0]
    for i in range(1,w.size()):
        if w[i]>best: best=w[i]; idx=i
    return idx
