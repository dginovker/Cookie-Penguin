extends Node2D  # Change this back to Node2D

@onready var terrain_map = $"../Tiles/TerrainTileMapLayer"
@onready var obstacles_map = $"../Tiles/ObstaclesTileMapLayer"
@onready var spawn_timer = $SpawnTimer
@onready var multiplayer_spawner = $MultiplayerSpawner  # Reference to child MultiplayerSpawner

var spawnable_tiles := []
var SpikeySquareScene := preload("res://Scenes/characters/mobs/spikeysquare/SpikeySquare.tscn")

func _ready():
	if not multiplayer.is_server():
		return
	
	# One-time setup
	var terrain_tiles = terrain_map.get_used_cells()
	var obstacle_tiles = obstacles_map.get_used_cells()
	
	var tile_dict = {}
	for tile in terrain_tiles:
		tile_dict[tile] = true
	for tile in obstacle_tiles:
		tile_dict.erase(tile)
	
	spawnable_tiles = tile_dict.keys()
	spawn_timer.timeout.connect(_on_SpawnTimer_timeout)

func _on_SpawnTimer_timeout():
	if not multiplayer.is_server():
		return
		
	if spawnable_tiles.is_empty():
		return
	
	var tile = spawnable_tiles.pick_random()
	var world_pos = _tile_to_world_pos(tile)
	
	if _is_spawn_area_clear(world_pos):
		var mob = SpikeySquareScene.instantiate()
		mob.global_position = world_pos
		add_child(mob, true)  # MultiplayerSpawner will detect this and sync

func _tile_to_world_pos(tile: Vector2i) -> Vector2:
	var tile_size = terrain_map.tile_set.tile_size
	return Vector2(tile) * Vector2(tile_size) + Vector2(tile_size) / 2

func _world_to_tile_pos(pos: Vector2) -> Vector2i:
	var tile_size = terrain_map.tile_set.tile_size
	return Vector2i((pos - Vector2(tile_size) / 2) / Vector2(tile_size))

func _is_spawn_area_clear(pos: Vector2) -> bool:
	var tile_size = terrain_map.tile_set.tile_size.x
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
