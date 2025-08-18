# TerrainMask.gd
class_name TerrainMask
extends Resource

@export var origin := Vector2.ZERO
@export var mask0: Texture2D
@export var mask1: Texture2D
@export var mask2: Texture2D
@export var layer_names := PackedStringArray()

func _img(tex: Texture2D) -> Image:
    return tex.get_image()

func _px(xz: Vector2) -> Vector2i:
    var p := xz - origin
    return Vector2i(int(p.x), int(p.y))

func weights_at(xz: Vector2) -> PackedFloat32Array:
    var i0 := _img(mask0)
    var i1 := _img(mask1)
    var i2 := _img(mask2)
    var p  := _px(xz)

    var a := i0.get_pixelv(p)
    var b := i1.get_pixelv(p)
    var c := i2.get_pixelv(p)

    return PackedFloat32Array([a.r, a.g, a.b, b.r, b.g, b.b, c.r, c.g, c.b])

# ---- helpers for per-layer queries ----

func _mask_image_for_index(idx: int) -> Image:
    @warning_ignore("integer_division")
    var which := idx / 3
    if which == 0:
        return mask0.get_image()
    elif which == 1:
        return mask1.get_image()
    else:
        return mask2.get_image()

func _channel_value(col: Color, ch: int) -> float:
    if ch == 0:
        return col.r
    elif ch == 1:
        return col.g
    else:
        return col.b

func weight_at_idx(xz: Vector2, idx: int) -> float:
    var img := _mask_image_for_index(idx)
    var p   := _px(xz)
    var col := img.get_pixelv(p)
    var ch  := idx % 3
    return _channel_value(col, ch)

# Central-difference gradient (world XZ) for one layer
func gradient_at_idx(xz: Vector2, idx: int) -> Vector2:
    var img := _mask_image_for_index(idx)
    var ch  := idx % 3
    var p   := _px(xz)

    var sx := img.get_width()
    var sy := img.get_height()

    var l := img.get_pixel(clamp(p.x - 1, 0, sx - 1), p.y)
    var r := img.get_pixel(clamp(p.x + 1, 0, sx - 1), p.y)
    var d := img.get_pixel(p.x, clamp(p.y - 1, 0, sy - 1))
    var u := img.get_pixel(p.x, clamp(p.y + 1, 0, sy - 1))

    var ddx := (_channel_value(r, ch) - _channel_value(l, ch)) * 0.5
    var ddz := (_channel_value(u, ch) - _channel_value(d, ch)) * 0.5

    return Vector2(ddx, ddz)
