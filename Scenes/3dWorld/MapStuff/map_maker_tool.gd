@tool
extends Node

@export var bake_now := false:
    set(_v): bake()

@export var source_path = "res://Scenes/3dWorld/MapStuff/terrain_index.png"
@export var mask0_path  = "res://Scenes/3dWorld/MapStuff/mask0.png"   # RGB carries layers 0..2
@export var mask1_path  = "res://Scenes/3dWorld/MapStuff/mask1.png"   # RGB carries layers 3..5
@export var liquid_path = "res://Scenes/3dWorld/MapStuff/liquid.png"  # L8
@export var tolerance := 0.04

@export var palette := PackedColorArray([
    Color.html("#96F06E"), # 0 grass
    Color.html("#FFFFBE"), # 1 sand
    Color.html("#4BAF00"), # 2 forest
    Color.html("#7A7F8C"), # 3 rock
    Color.html("#AEE7FF"), # 4 ice
    Color.html("#4E4E4E")  # 5 desolate
])

@export var liquid_color := Color.html("#6EC8FA") # any exact swatch you paint for liquid

func bake():
    var img := (load(source_path) as Texture2D).get_image(); img.convert(Image.FORMAT_RGBA8)
    var w=img.get_width(); var h=img.get_height()
    var m0 := Image.create(w,h,false,Image.FORMAT_RGBA8); m0.fill(Color(0,0,0,1))
    var m1 := Image.create(w,h,false,Image.FORMAT_RGBA8); m1.fill(Color(0,0,0,1))
    var li := Image.create(w,h,false,Image.FORMAT_L8);    li.fill(Color(0,0,0))
    var t2 := tolerance*tolerance

    for y in h:
        for x in w:
            var c := img.get_pixel(x,y)
            var dr=c.r-liquid_color.r; var dg=c.g-liquid_color.g; var db=c.b-liquid_color.b
            if dr*dr+dg*dg+db*db <= t2: li.set_pixel(x,y, Color(1,1,1)); continue

            var best=1e9; var idx=0
            for i in palette.size():
                var p=palette[i]; var d=(c.r-p.r)*(c.r-p.r)+(c.g-p.g)*(c.g-p.g)+(c.b-p.b)*(c.b-p.b)
                if d<best: best=d; idx=i

            if idx<3:
                var p0=m0.get_pixel(x,y)
                if idx==0: p0.r=1.0
                elif idx==1: p0.g=1.0
                else: p0.b=1.0
                m0.set_pixel(x,y,p0)
            else:
                var p1=m1.get_pixel(x,y)
                if idx==3: p1.r=1.0
                elif idx==4: p1.g=1.0
                else: p1.b=1.0
                m1.set_pixel(x,y,p1)

    m0.save_png(mask0_path); m1.save_png(mask1_path); li.save_png(liquid_path)
    print("baked")
