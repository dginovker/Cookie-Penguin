extends Node

@onready var spawn_timer = $SpawnTimer

var spawnable_tiles: Array[Vector3i] = []
var SpikeySquareScene := preload("res://Scenes/characters/mobs/spikeysquare3d/SpikeySquare3D.tscn")

func _ready():
    if not multiplayer.is_server():
        return
    
    # One-time setup
    spawnable_tiles = ($"../Map/GridMap" as GridMap).get_used_cells()
    spawn_timer.timeout.connect(_on_SpawnTimer_timeout)

func _on_SpawnTimer_timeout():
    if not multiplayer.is_server():
        return
        
    if spawnable_tiles.is_empty():
        return
    
    var tile: Vector3i = spawnable_tiles.pick_random()
    var world_pos = _tile_to_world_pos(tile)
    assert(world_pos.y == 0)# ISSUE
    
    if _is_spawn_area_clear(world_pos):
        var mob = SpikeySquareScene.instantiate()
        add_child(mob, true)  # MultiplayerSpawner will detect this and sync
        mob.global_position = world_pos

# TODO - simplify this
func _tile_to_world_pos(tile: Vector3i) -> Vector3:
    return Vector3(tile.x, tile.y, tile.z) + Vector3(1.0, 2.0, 1.0) / 2

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
