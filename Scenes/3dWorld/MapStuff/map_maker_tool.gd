@tool
extends Node

@export var bake_now := false:
    set(_v): bake()

var source_path  = "res://Scenes/3dWorld/MapStuff/terrain_index.png"
var mask0_path   = "res://Scenes/3dWorld/MapStuff/mask0.png"
var mask1_path   = "res://Scenes/3dWorld/MapStuff/mask1.png"
var liquids_path = "res://Scenes/3dWorld/MapStuff/liquids.png"

# byte tolerance per channel (0..255). 0 = exact; bump to 2–4 if your editor nudges colors.
var tol8 := 0

# terrain palette (0..5 -> mask0.rgb/mask1.rgb)
var palette := PackedColorArray([
    Color.html("#96F06E"), # 0 grass
    Color.html("#FFFFBE"), # 1 sand
    Color.html("#4BAF00"), # 2 forest
    Color.html("#4C4C4C"), # 3 plateau
    Color.html("#FFFFFF"), # 4 ice
    Color.html("#4E4E4E")  # 5 unused (for now)
])

# liquids (exact swatches in terrain_index.png)
var shallow_col := Color.html("#6EC8FA")
var deep_col    := Color.html("#143DA5")
var lava_col    := Color.html("#FFA500")

func _to_rgb8(c: Color) -> Vector3i:
    return Vector3i(int(round(c.r*255.0)), int(round(c.g*255.0)), int(round(c.b*255.0)))

func _eq_rgb8(a: Vector3i, b: Vector3i, t: int) -> bool:
    return abs(a.x-b.x) <= t && abs(a.y-b.y) <= t && abs(a.z-b.z) <= t

func bake():
    var tex := load(source_path) as Texture2D
    var img := tex.get_image(); img.convert(Image.FORMAT_RGBA8)
    var w = img.get_width(); var h = img.get_height()

    var m0 := Image.create(w,h,false,Image.FORMAT_RGBA8); m0.fill(Color(0,0,0,1))
    var m1 := Image.create(w,h,false,Image.FORMAT_RGBA8); m1.fill(Color(0,0,0,1))
    var li := Image.create(w,h,false,Image.FORMAT_RGB8);  li.fill(Color(0,0,0,1))

    var p8 : Array = []
    for p in palette: p8.append(_to_rgb8(p))
    var sh8 = _to_rgb8(shallow_col)
    var dp8 = _to_rgb8(deep_col)
    var lv8 = _to_rgb8(lava_col)

    for y in h:
        for x in w:
            var v := _to_rgb8(img.get_pixel(x,y))

            if _eq_rgb8(v, sh8, tol8): li.set_pixel(x,y, Color(1,0,0)); continue
            if _eq_rgb8(v, dp8, tol8): li.set_pixel(x,y, Color(0,1,0)); continue
            if _eq_rgb8(v, lv8, tol8): li.set_pixel(x,y, Color(0,0,1)); continue

            var best = 1e12; var idx = 0
            for i in p8.size():
                var pv: Vector3i = p8[i]
                var d = (v.x-pv.x)*(v.x-pv.x) + (v.y-pv.y)*(v.y-pv.y) + (v.z-pv.z)*(v.z-pv.z)
                if d < best: best = d; idx = i

            if idx < 3:
                var p0 = m0.get_pixel(x,y)
                if idx == 0: p0.r = 1.0
                elif idx == 1: p0.g = 1.0
                else: p0.b = 1.0
                m0.set_pixel(x,y, p0)
            else:
                var p1 = m1.get_pixel(x,y)
                if idx == 3: p1.r = 1.0
                elif idx == 4: p1.g = 1.0
                else: p1.b = 1.0
                m1.set_pixel(x,y, p1)

    m0.save_png(mask0_path); m1.save_png(mask1_path); li.save_png(liquids_path)
    print("baked")
