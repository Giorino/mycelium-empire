class_name CaveWorld
extends Node2D

## Manages the cave world, rendering and interaction
## Uses CaveGenerator to create procedural caves and displays them in TileMapLayer

@export var auto_generate_on_ready: bool = true

# Node references
@onready var cave_generator: Node = $CaveGenerator
@onready var tile_layer: TileMapLayer = $TileMapLayer
@onready var mycelium_manager: Node = $MyceliumManager


# Tile types (matching CaveGenerator.TileType enum)
enum TileType {
	EMPTY = 0,
	WALL = 1,
	NUTRIENT = 2
}

# Tile atlas coordinates for different tile types
const EMPTY_TILE = Vector2i(-1, -1)  # No tile (transparent)
const WALL_TILE = Vector2i(0, 0)     # Wall tile
const NUTRIENT_TILE = Vector2i(1, 0) # Nutrient vein tile

# Tileset source ID (usually 0 for first tileset)
const TILESET_SOURCE_ID = 0

func _ready() -> void:
	if auto_generate_on_ready:
		generate_new_cave()


## Generate a new cave and render it
func generate_new_cave() -> void:
	print("Generating new cave...")

	# Clear existing mycelium before generating a new cave
	if mycelium_manager:
		mycelium_manager.clear_all()

	var start_time = Time.get_ticks_msec()

	# Generate cave data
	var cave_data = cave_generator.generate()

	# Render to TileMapLayer
	_render_cave(cave_data)

	var elapsed = Time.get_ticks_msec() - start_time
	print("Cave generated in %d ms" % elapsed)


## Render cave data to TileMapLayer
func _render_cave(cave_data: Array) -> void:
	if not tile_layer:
		push_error("TileMapLayer not found! Make sure CaveWorld scene has a TileMapLayer child node.")
		return

	# Clear existing tiles
	tile_layer.clear()

	# Render each tile
	for y in range(cave_generator.cave_height):
		for x in range(cave_generator.cave_width):
			var index = y * cave_generator.cave_width + x
			var tile_type = cave_data[index]

			var atlas_coord: Vector2i

			match tile_type:
				TileType.EMPTY:
					# Don't place a tile (leave as transparent/floor)
					continue
				TileType.WALL:
					atlas_coord = WALL_TILE
				TileType.NUTRIENT:
					atlas_coord = NUTRIENT_TILE

			# Place tile at grid position
			tile_layer.set_cell(Vector2i(x, y), TILESET_SOURCE_ID, atlas_coord)


## Get tile type at world position
func get_tile_at_position(world_pos: Vector2) -> int:
	var map_pos = tile_layer.local_to_map(world_pos)
	var tile_data = tile_layer.get_cell_tile_data(map_pos)

	if tile_data == null:
		return TileType.EMPTY

	var atlas_coord = tile_layer.get_cell_atlas_coords(map_pos)

	if atlas_coord == WALL_TILE:
		return TileType.WALL
	elif atlas_coord == NUTRIENT_TILE:
		return TileType.NUTRIENT
	else:
		return TileType.EMPTY


## Destroy tile at world position (for harvesting)
func destroy_tile_at_position(world_pos: Vector2) -> bool:
	var map_pos = tile_layer.local_to_map(world_pos)
	var tile_data = tile_layer.get_cell_tile_data(map_pos)

	if tile_data == null:
		return false

	# Remove the tile
	tile_layer.erase_cell(map_pos)
	return true


## Get cave bounds in world coordinates
func get_cave_bounds() -> Rect2:
	var tile_size = tile_layer.tile_set.tile_size if tile_layer.tile_set else Vector2i(16, 16)
	return Rect2(
		Vector2.ZERO,
		Vector2(cave_generator.cave_width * tile_size.x, cave_generator.cave_height * tile_size.y)
	)
