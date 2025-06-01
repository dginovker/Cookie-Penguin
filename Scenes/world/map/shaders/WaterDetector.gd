class_name WaterDetector
extends Node

signal water_status_changed(in_water: bool)

var tilemap_layer: TileMapLayer
var target_sprite: Node2D
var shader_material: ShaderMaterial
var is_in_water = false
var last_tile_pos = Vector2i(-999, -999)

func setup(sprite: Node2D):
    target_sprite = sprite

    tilemap_layer = get_tilemap_layer()

    if not tilemap_layer:
        push_warning("WaterDetector: Could not find tilemap layer")
        return

    # Create and apply shader material
    shader_material = ShaderMaterial.new()
    shader_material.shader = load("res://Scenes/world/map/shaders/water_submersion.gdshader")
    target_sprite.material = shader_material
    shader_material.set_shader_parameter("in_water", false)

func get_tilemap_layer():
    if not tilemap_layer:
        tilemap_layer = get_node_or_null("/root/Game/MapNode/Tiles/TerrainTileMapLayer")
    return tilemap_layer

func check_water_status(global_pos: Vector2):
    # Use different positions for checking based on current water status
    var check_pos = global_pos
    
    # If we're currently in water, check slightly upward to prevent oscillation
    # when exiting water from below
    if is_in_water:
        check_pos.y -= 8  # Half the teleport distance
    
    var current_tile_pos = get_tilemap_layer().local_to_map(check_pos)

    # Only check if we've moved to a different tile
    if current_tile_pos != last_tile_pos:
        last_tile_pos = current_tile_pos

        var tile_data = tilemap_layer.get_cell_tile_data(current_tile_pos)
        var new_water_status = false

        if tile_data:
            new_water_status = tile_data.get_custom_data("is_water")

        if new_water_status != is_in_water:
            is_in_water = new_water_status
            shader_material.set_shader_parameter("in_water", is_in_water)
            water_status_changed.emit(is_in_water)
