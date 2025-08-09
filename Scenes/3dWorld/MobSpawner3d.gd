extends MultiplayerSpawner

@export var spawn_timer: Timer
@export var easylands_gridmap: GridMap

var easylands_tiles: Array[Vector3i] = []
var easyland_mobs: Array[String] = ["spikey_square"]

var mob_resources: Dictionary[String, Resource] = {
    "spikey_square": preload("res://Scenes/mobs/spikeysquare3d/SpikeySquare3D.tscn")
}

func _enter_tree() -> void:
    spawn_function = _spawn_player_custom

func _ready():
    if not multiplayer.is_server():
        return

    # One-time setup
    easylands_tiles = easylands_gridmap.get_used_cells()

    spawn_timer.timeout.connect(_on_SpawnTimer_timeout)

func _spawn_player_custom(data: Variant) -> Node:
    # data = [Vector3 (pos), String (mob name)]
    var mob = mob_resources[(data[1] as String)].instantiate()
    mob.position = data[0] as Vector3
    mob.add_to_group("mobs")
    mob.set_multiplayer_authority(1)
    return mob

func _on_SpawnTimer_timeout():
    if not multiplayer.is_server():
        return

    _try_spawn(easylands_tiles, easyland_mobs)

func _try_spawn(tiles: Array[Vector3i], mobs: Array[String]):
    assert(!tiles.is_empty())
    assert(!mobs.is_empty())
    
    var tile: Vector3i = tiles.pick_random()
    var world_pos = Vector3(tile.x, tile.y, tile.z) + Vector3(0.5, 2.0, 0.5)

    if _is_spawn_area_clear(world_pos):
        spawn([world_pos, mobs.pick_random()])
        
func _is_spawn_area_clear(pos: Vector3) -> bool:
    var tile_size = 1
    var min_distance = tile_size * 8

    # Check players
    for player in get_tree().get_nodes_in_group("players"):
        if pos.distance_to(player.global_position) < min_distance:
            return false

    # Check mobs
    for mob in get_tree().get_nodes_in_group("mobs"):
        if pos.distance_to(mob.global_position) < min_distance:
            return false

    return true
