class_name TerrainMask
extends Resource

@export var mask0: Texture2D
@export var mask1: Texture2D
@export var mask2: Texture2D

# --- Simple cache: grab Images once; no per-call GPU→CPU readbacks ---
var img0: Image
var img1: Image
var img2: Image
var prepared: bool = false

func _prepare() -> void:
    # Convert once to a predictable format for fast reads
    # (I profiled this, _img_for_terrain was taking up to 15ms/frame before..)
    img0 = mask0.get_image(); if img0.get_format() != Image.FORMAT_RGB8: img0.convert(Image.FORMAT_RGB8)
    img1 = mask1.get_image(); if img1.get_format() != Image.FORMAT_RGB8: img1.convert(Image.FORMAT_RGB8)
    img2 = mask2.get_image(); if img2.get_format() != Image.FORMAT_RGB8: img2.convert(Image.FORMAT_RGB8)
    prepared = true

func _img_for_terrain(terrain: int) -> Image:
    if !prepared: _prepare()
    @warning_ignore("integer_division")
    var which: int = terrain / 3
    if which == 0: return img0
    if which == 1: return img1
    return img2

func _ch(c: Color, ch: int) -> float:
    if ch == 0: return c.r
    if ch == 1: return c.g
    return c.b

func _px(xz: Vector2) -> Vector2i:
    return Vector2i(int(xz.x), int(xz.y))

# --- API (unchanged signatures) ---

func weights_at(xz: Vector2) -> PackedFloat32Array:
    var p: Vector2i = _px(xz)
    # Use cached Images; avoid calling get_image() each time
    var a: Color = _img_for_terrain(0).get_pixelv(p)
    var b: Color = _img_for_terrain(3).get_pixelv(p)
    var c: Color = _img_for_terrain(6).get_pixelv(p)
    return PackedFloat32Array([a.r, a.g, a.b, b.r, b.g, b.b, c.r, c.g, c.b])

func weight_at(xz: Vector2, terrain: int) -> float:
    var p: Vector2i = _px(xz)
    var col: Color = _img_for_terrain(terrain).get_pixelv(p)
    return _ch(col, terrain % 3)

func is_in(xz: Vector3, terrain: int, threshold: float = 0.5) -> bool:
    return weight_at(Vector2(xz.x, xz.z), terrain) >= threshold
