# MobManager.gd (spawns mobs, but not actually a MultiplayerSpawner)
extends Node
class_name RealmMobManager

@export var spawn_timer: Timer
@export var terrain: TerrainMask      # the .tres you saved from your baker
@export var spawn_height := 0.1      # vertical offset above ground

var _mob_index := 0
var spawned_mobs: Dictionary[int, MobNode]

# choose which mask-layer indices are valid for each region (exclude liquid indices)
var easy_layers := PackedInt32Array([0, 1])       # e.g., grass, sand
var mid_layers  := PackedInt32Array([2, 3, 4, 5]) # e.g., forest, plateau, ice, desolate

var easy_mobs := Array(["spikey_square"])
var mid_mobs  := Array(["lolipop"])

var min_distance := 8.0        # meters to keep away from players/other mobs
var stride_px := 1             # sample every N mask pixels (1 = every pixel)

var easy_positions: Array[Vector3] = []
var mid_positions:  Array[Vector3] = []

var mob_resources := {
    "spikey_square": preload("res://Scenes/mobs/spikeysquare3d/SpikeySquare3D.tscn"),
    "lolipop":       preload("res://Scenes/mobs/lolipop/Lolipop.tscn"),
}

func _ready():
    if !multiplayer.is_server(): return
    assert(get_tree().get_first_node_in_group("mob_holder") != null)
    easy_positions = _bake_positions(easy_layers)
    mid_positions  = _bake_positions(mid_layers)

    spawn_timer.timeout.connect(_on_spawn_timer)

func spawn(pos: Vector3, kind: String, id: int = -1) -> MobNode:
    # Called locally
    if multiplayer.is_server():
        assert(id == -1)
    var mob: MobNode = (mob_resources[kind] as PackedScene).instantiate()
    if (multiplayer.is_server()):
        #print("Spawned node with id ", _mob_index)
        mob.mob_id = _mob_index
        _mob_index += 1
    else:
        # Clients use the server-provided mob id
        mob.mob_id = id
    spawned_mobs[mob.mob_id] = mob
    mob.mob_kind = kind
    mob.name = "mob_%d" % mob.mob_id
    mob.set_multiplayer_authority(1)
    get_tree().get_first_node_in_group("mob_holder").add_child(mob)
    mob.global_position = Vector3(pos.x, spawn_height, pos.z)
    return mob

func _bake_positions(layers: PackedInt32Array)->Array[Vector3]:
    var i0 = terrain.mask0.get_image()
    var i1 = terrain.mask1.get_image()
    var i2 = terrain.mask2.get_image()
    var w = i0.get_width(); var h = i0.get_height()
    var out: Array[Vector3] = []
    for yy in range(0, h, stride_px):
        for xx in range(0, w, stride_px):
            var a = i0.get_pixel(xx, yy)
            var b = i1.get_pixel(xx, yy)
            var c = i2.get_pixel(xx, yy)
            var wts = [a.r, a.g, a.b, b.r, b.g, b.b, c.r, c.g, c.b]
            var idx = 0; var best = wts[0]
            for k in range(1,9):
                if wts[k] > best:
                    best = wts[k]
                    idx = k
            for L in layers:
                if idx == L:
                    var spawn_x = xx + 0.5
                    var spawn_z = yy + 0.5
                    out.append(Vector3(spawn_x, 0.1, spawn_z))
                    break
    return out

func _on_spawn_timer():
    if !multiplayer.is_server(): return
    _try_spawn(easy_positions, easy_mobs)
    _try_spawn(mid_positions,  mid_mobs)

func _try_spawn(positions: Array[Vector3], mobs: Array):
    var pos = positions.pick_random()
    if _is_clear(pos):
        spawn(pos, mobs.pick_random())

func _is_clear(pos: Vector3)->bool:
    var d = min_distance
    for p in get_tree().get_nodes_in_group("players"):
        if pos.distance_to(p.global_position) < d: return false
    for m in get_tree().get_nodes_in_group("mobs"):
        if pos.distance_to(m.global_position) < d: return false
    return true
