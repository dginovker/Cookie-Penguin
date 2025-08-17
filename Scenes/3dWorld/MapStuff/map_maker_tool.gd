# MapBake.gd
@tool
extends Node

@export var bake_now := false:
    set(_v): bake()

var source_path  = "res://Scenes/3dWorld/MapStuff/terrain_index.png"
var out_dir      = "res://Scenes/3dWorld/MapStuff"

var ppm := 1.0            # pixels per meter in your painted map
var tol8 := 0             # 0..4 if your editor nudges channel values

# up to 9 layers; order matters (0..8)
var layer_names := PackedStringArray([
    "grass","sand","forest","plateau","ice","desolate","shallow","deep","lava"
])
var layer_colors := PackedColorArray([
    Color.html("#96F06E"),
    Color.html("#FFFFBE"),
    Color.html("#4BAF00"),
    Color.html("#4C4C4C"),
    Color.html("#FFFFFF"),
    Color.html("#4E4E4E"),
    Color.html("#6EC8FA"),
    Color.html("#143DA5"),
    Color.html("#FFA500")
])

func _mask_path(i:int)->String: return out_dir + "/mask%d.png" % i
func _tres_path()->String: return out_dir + "/TerrainMask.tres"

func _rgb8(c:Color)->Vector3i: return Vector3i(int(round(c.r*255.0)), int(round(c.g*255.0)), int(round(c.b*255.0)))
func _eq(a:Vector3i,b:Vector3i,t:int)->bool: return abs(a.x-b.x)<=t && abs(a.y-b.y)<=t && abs(a.z-b.z)<=t

func bake():
    var img := (load(source_path) as Texture2D).get_image(); img.convert(Image.FORMAT_RGBA8)
    var w = img.get_width(); var h = img.get_height()

    var masks := [
        Image.create(w,h,false,Image.FORMAT_RGBA8),
        Image.create(w,h,false,Image.FORMAT_RGBA8),
        Image.create(w,h,false,Image.FORMAT_RGBA8)
    ]
    for m in masks: m.fill(Color(0,0,0,1))

    var pal8:Array = []; for c in layer_colors: pal8.append(_rgb8(c))

    for y in h:
        for x in w:
            var v := _rgb8(img.get_pixel(x,y))
            var best := 1e12; var idx := 0
            for i in pal8.size():
                var p:Vector3i = pal8[i]
                var d = (v.x-p.x)*(v.x-p.x) + (v.y-p.y)*(v.y-p.y) + (v.z-p.z)*(v.z-p.z)
                if d < best: best = d; idx = i
            if !_eq(v, pal8[idx], tol8): continue

            var mi = idx / 3          # which mask image (0,1,2)
            var ch = idx % 3          # which channel   (R,G,B)
            var px = masks[mi].get_pixel(x,y)
            if ch==0: px.r=1.0
            elif ch==1: px.g=1.0
            else: px.b=1.0
            masks[mi].set_pixel(x,y, px)

    # write PNGs for materials
    for i in 3: masks[i].save_png(_mask_path(i))

    # build ImageTextures directly; no importer race
    var T0 := ImageTexture.create_from_image(masks[0])
    var T1 := ImageTexture.create_from_image(masks[1])
    var T2 := ImageTexture.create_from_image(masks[2])

    # write a shared resource for gameplay sampling
    var tm := TerrainMask.new()
    tm.ppm = ppm
    tm.origin = Vector2.ZERO     # you set this per-scene once, see below
    tm.mask0 = T0; tm.mask1 = T1; tm.mask2 = T2
    tm.layer_names = layer_names
    ResourceSaver.save(tm, _tres_path())
    print("baked")
