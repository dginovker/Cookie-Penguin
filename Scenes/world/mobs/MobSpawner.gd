extends Node2D

@onready var terrain_map = $"../Tiles/TerrainTileMapLayer"
@onready var obstacles_map = $"../Tiles/ObstaclesTileMapLayer"
@onready var spawn_timer = $SpawnTimer

var spawnable_tiles := []
var PenguinScene := preload("res://Scenes/characters/mobs/spikeysquare/SpikeySquare.tscn")

func _ready():
	# Collect valid spawn tiles (already calculated in your earlier logic)
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
	print("on_spawnertimer_timeout")
	if spawnable_tiles.is_empty():
		return
	
	var tile = spawnable_tiles.pick_random()
	var tile_size = terrain_map.tile_set.tile_size  # Vector2i
	var tile_pos_vec2 = Vector2(tile.x, tile.y)    # convert tile Vector2i to Vector2
	var tile_size_vec2 = Vector2(tile_size.x, tile_size.y)  # convert tile_size Vector2i to Vector2

	var world_pos = tile_pos_vec2 * tile_size_vec2 + tile_size_vec2 / 2
	
	if not _is_spawn_area_clear(world_pos):
		return

	var mob = PenguinScene.instantiate()
	mob.global_position = world_pos
	get_tree().get_root().add_child(mob)

func _is_spawn_area_clear(pos: Vector2) -> bool:
	var space_state = get_world_2d().direct_space_state
	
	var shape := CircleShape2D.new()
	shape.radius = 64  # adjust as needed

	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0, pos)
	query.collide_with_areas = true
	query.collide_with_bodies = true

	var results = space_state.intersect_shape(query)

	for result in results:
		var collider = result.get("collider")
		if collider.is_in_group("player") or collider.is_in_group("mobs"):
			return false

	return true
