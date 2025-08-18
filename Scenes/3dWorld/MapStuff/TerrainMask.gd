class_name TerrainMask
extends Resource

@export var mask0: Texture2D               # RGB → 0..2
@export var mask1: Texture2D               # RGB → 3..5
@export var mask2: Texture2D               # RGB → 6..8

func _img_for_terrain(terrain: int)->Image:
    @warning_ignore("integer_division")
    var which := terrain / 3
    if which == 0: return mask0.get_image()
    if which == 1: return mask1.get_image()
    return mask2.get_image()

func _ch(c:Color, ch:int)->float:
    if ch == 0: return c.r
    if ch == 1: return c.g
    return c.b

func _px(xz:Vector2)->Vector2i:
    return Vector2i(int(xz.x), int(xz.y))

func weights_at(xz:Vector2)->PackedFloat32Array:
    var p := _px(xz)
    var a := mask0.get_image().get_pixelv(p)
    var b := mask1.get_image().get_pixelv(p)
    var c := mask2.get_image().get_pixelv(p)
    return PackedFloat32Array([a.r,a.g,a.b, b.r,b.g,b.b, c.r,c.g,c.b])

func weight_at(xz:Vector2, terrain:int)->float:
    var p := _px(xz)
    var col := _img_for_terrain(terrain).get_pixelv(p)
    return _ch(col, terrain % 3)

func is_in(xz:Vector3, terrain:int, threshold:float=0.5)->bool:
    return weight_at(Vector2(xz.x, xz.z), terrain) >= threshold
