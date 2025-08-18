@tool
extends Node

@export var bake_now := false:
    set(_v): bake()

var source_path := "res://Scenes/3dWorld/MapStuff/terrain_index.png"
var out_dir     := "res://Scenes/3dWorld/MapStuff"

var tol8 := 0            # channel tolerance 0..4 if editor nudges colors

# ---- Authoritative terrain enum + palette ----
enum Terrain { GRASS, SAND, FOREST, PLATEAU, ICE, DESOLATE, SHALLOW, DEEP, LAVA }

const TERRAIN_DATA := {
    Terrain.GRASS:   { "index": 0, "color": "#96F06E" },
    Terrain.SAND:    { "index": 1, "color": "#FFFFBE" },
    Terrain.FOREST:  { "index": 2, "color": "#4BAF00" },
    Terrain.PLATEAU: { "index": 3, "color": "#4C4C4C" },
    Terrain.ICE:     { "index": 4, "color": "#FFFFFF" },
    Terrain.DESOLATE:{ "index": 5, "color": "#4E4E4E" },
    Terrain.SHALLOW: { "index": 6, "color": "#6EC8FA" },
    Terrain.DEEP:    { "index": 7, "color": "#143DA5" },
    Terrain.LAVA:    { "index": 8, "color": "#FFA500" },
}
# Indices must be contiguous 0..8; enum values should match those indices.

func _mask_path(i:int)->String: return "%s/mask%d.png" % [out_dir, i]
func _tres_path()->String:      return "%s/TerrainMask.tres" % out_dir

func _rgb8(c:Color)->Vector3i:
    return Vector3i(int(round(c.r*255.0)), int(round(c.g*255.0)), int(round(c.b*255.0)))

func _eq(a:Vector3i,b:Vector3i,t:int)->bool:
    return abs(a.x-b.x)<=t && abs(a.y-b.y)<=t && abs(a.z-b.z)<=t

func bake():
    # Build palette lists once from TERRAIN_DATA
    var pal_colors  : Array[Color]    = []
    var pal_colors8 : Array[Vector3i] = []
    var pal_indices : Array[int]      = []  # 0..8 terrain layer index for each color swatch

    for t in TERRAIN_DATA.keys():
        var idx:int = TERRAIN_DATA[t]["index"]
        var col:Color = Color.html(TERRAIN_DATA[t]["color"])
        pal_colors.append(col)
        pal_colors8.append(_rgb8(col))
        pal_indices.append(idx)

    # 3 output masks (RGB each) → up to 9 layers
    var src := (load(source_path) as Texture2D).get_image(); src.convert(Image.FORMAT_RGBA8)
    var w = src.get_width(); var h = src.get_height()
    var masks := [
        Image.create(w,h,false,Image.FORMAT_RGBA8),
        Image.create(w,h,false,Image.FORMAT_RGBA8),
        Image.create(w,h,false,Image.FORMAT_RGBA8),
    ]
    for m in masks: m.fill(Color(0,0,0,1))

    var t2 := tol8*tol8
    for y in h:
        for x in w:
            var v := _rgb8(src.get_pixel(x,y))
            # nearest palette color
            var best := 1e12; var pick := 0
            for i in pal_colors8.size():
                var p:Vector3i = pal_colors8[i]
                var d = (v.x-p.x)*(v.x-p.x) + (v.y-p.y)*(v.y-p.y) + (v.z-p.z)*(v.z-p.z)
                if d < best: best = d; pick = i
            if !_eq(v, pal_colors8[pick], tol8): continue

            var idx:int = pal_indices[pick]      # 0..8 terrain layer
            var mi:int  = idx / 3               # which mask (0..2)
            var ch:int  = idx % 3               # which channel (0..2)
            var px = masks[mi].get_pixel(x,y)
            if ch == 0: px.r = 1.0
            elif ch == 1: px.g = 1.0
            else: px.b = 1.0
            masks[mi].set_pixel(x,y, px)

    # Save PNGs for materials (editor-friendly) and also embed textures for runtime sampling
    for i in 3: masks[i].save_png(_mask_path(i))
    var T0 := ImageTexture.create_from_image(masks[0])
    var T1 := ImageTexture.create_from_image(masks[1])
    var T2 := ImageTexture.create_from_image(masks[2])

    # Write shared resource
    var tm := TerrainMask.new()
    tm.origin = Vector2.ZERO      # set this per-scene to match your ground material
    tm.mask0  = T0; tm.mask1 = T1; tm.mask2 = T2
    # Optional: store the enum→index table so gameplay can assert consistency
    var map := {}
    for t in TERRAIN_DATA.keys():
        map[int(t)] = TERRAIN_DATA[t]["index"]
    tm.enum_to_index = map
    ResourceSaver.save(tm, _tres_path())
    print("baked")
