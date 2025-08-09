extends MultiplayerSpawner

@export var spawn_timer: Timer
@export var gridmap: GridMap

var spawnable_tiles: Array[Vector3i] = []
var SpikeySquareScene := preload("res://Scenes/mobs/spikeysquare3d/SpikeySquare3D.tscn")

func _enter_tree() -> void:
    spawn_function = _spawn_player_custom

func _ready():
    if not multiplayer.is_server():
        return

    # One-time setup
    spawnable_tiles = gridmap.get_used_cells()
    spawn_timer.timeout.connect(_on_SpawnTimer_timeout)

func _spawn_player_custom(data: Variant) -> Node:
    var mob = SpikeySquareScene.instantiate()
    mob.position = data as Vector3
    mob.add_to_group("mobs")
    mob.set_multiplayer_authority(1)
    return mob

func _on_SpawnTimer_timeout():
    if not multiplayer.is_server():
        return

    if spawnable_tiles.is_empty():
        return

    var tile: Vector3i = spawnable_tiles.pick_random()
    var world_pos = Vector3(tile.x, tile.y, tile.z) + Vector3(0.5, 2.0, 0.5)

    if _is_spawn_area_clear(world_pos):
        spawn(world_pos)
        
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
