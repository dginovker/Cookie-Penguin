@tool
extends Node

@export var bake_now := false:
    set(_v): bake()

var source_path := "res://Scenes/3dWorld/MapStuff/terrain_index.png"
var out_dir     := "res://Scenes/3dWorld/MapStuff"
var tol8 := 0                                        # per-channel tolerance 0..4

func _mask_path(i:int)->String: return "%s/mask%d.png" % [out_dir, i]
func _tres_path()->String:      return "%s/TerrainMask.tres" % out_dir

func _rgb8(c:Color)->Vector3i:
    return Vector3i(int(round(c.r*255.0)), int(round(c.g*255.0)), int(round(c.b*255.0)))

func _eq(a:Vector3i,b:Vector3i,t:int)->bool:
    return abs(a.x-b.x)<=t && abs(a.y-b.y)<=t && abs(a.z-b.z)<=t

func bake():
    var src := (load(source_path) as Texture2D).get_image()
    src.convert(Image.FORMAT_RGBA8)
    var w = src.get_width(); var h = src.get_height()

    # 3 RGB masks → 9 layers max
    var masks := [
        Image.create(w,h,false,Image.FORMAT_RGBA8),
        Image.create(w,h,false,Image.FORMAT_RGBA8),
        Image.create(w,h,false,Image.FORMAT_RGBA8),
    ]
    for m in masks: m.fill(Color(0,0,0,1))

    # Build palette arrays once from Autoload
    var pal8:Array[Vector3i] = []
    for hx in TerrainDefs.COLORS_HEX:
        pal8.append(_rgb8(TerrainDefs.color_from_hex(hx)))

    for y in h:
        for x in w:
            var v := _rgb8(src.get_pixel(x,y))
            var best := 1e12; var idx := 0
            for i in pal8.size():
                var p:Vector3i = pal8[i]
                var d = (v.x-p.x)*(v.x-p.x) + (v.y-p.y)*(v.y-p.y) + (v.z-p.z)*(v.z-p.z)
                if d < best: best = d; idx = i
            if !_eq(v, pal8[idx], tol8): continue

            @warning_ignore("integer_division")
            var mi := idx / 3        # 0..2
            var ch := idx % 3        # 0..2
            var px = masks[mi].get_pixel(x,y)
            if ch==0: px.r = 1.0
            elif ch==1: px.g = 1.0
            else: px.b = 1.0
            masks[mi].set_pixel(x,y, px)

    # Save PNGs for materials
    for i in 3: masks[i].save_png(_mask_path(i))

    # Build ImageTextures for runtime sampling; store origin later in-scene
    var T0 := ImageTexture.create_from_image(masks[0])
    var T1 := ImageTexture.create_from_image(masks[1])
    var T2 := ImageTexture.create_from_image(masks[2])

    var tm := TerrainMask.new()
    tm.mask0 = T0; tm.mask1 = T1; tm.mask2 = T2
    var res := ResourceSaver.save(tm, _tres_path())
    print("baked: ", res)
