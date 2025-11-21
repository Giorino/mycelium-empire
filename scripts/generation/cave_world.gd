class_name CaveWorld
extends Node2D
@export_group("cave_world")  # Group for easy lookup

## Manages the cave world, rendering and interaction
## Uses CaveGenerator to create procedural caves and displays them in TileMapLayer

@export var auto_generate_on_ready: bool = true

# Node references
@onready var cave_generator: Node = $CaveGenerator
@onready var tile_layer: TileMapLayer = $TileMapLayer
@onready var mycelium_manager: Node = $MyceliumManager
@onready var minion_manager: Node = $MinionManager

# Tile types (matching CaveGenerator.TileType enum)
enum TileType {
	EMPTY = 0,
	WALL = 1,
	NUTRIENT = 2
}

# Tile atlas coordinates for different tile types
const EMPTY_TILE = Vector2i(-1, -1)  # No tile (transparent)
const WALL_TILE = Vector2i(0, 0)     # Wall tile

# Vein tiles start at atlas position (1, 0) and use bitmask for connections
# Bitmask: UP=1, RIGHT=2, DOWN=4, LEFT=8
# Index = 1 + bitmask value (so tile at x=1 is isolated vein, x=2 is up connection, etc.)
const VEIN_TILE_START = Vector2i(1, 0)

# Tileset source ID (usually 0 for first tileset)
const TILESET_SOURCE_ID = 0

# Bitmask values for vein connections
const CONNECT_UP = 1
const CONNECT_RIGHT = 2
const CONNECT_DOWN = 4
const CONNECT_LEFT = 8

# Store cave data for neighbor checks during rendering
var cave_data: Array = []

func _ready() -> void:
	add_to_group("cave_world")
	if auto_generate_on_ready:
		generate_new_cave()


## Generate a new cave and render it
func generate_new_cave() -> void:
	print("Generating new cave...")

	# Clear existing mycelium before generating a new cave
	if mycelium_manager:
		mycelium_manager.clear_all()
		mycelium_manager.set_starting_nutrients_to_default()

	if minion_manager:
		print("Resetting minion colony...")
		print("Minion count: %d" % minion_manager.get_minion_count())
		minion_manager.reset_colony()
		print("Minion count: %d" % minion_manager.get_minion_count())

	var start_time = Time.get_ticks_msec()

	# Generate cave data and store it
	cave_data = cave_generator.generate()

	# Render to TileMapLayer
	_render_cave(cave_data)

	var elapsed = Time.get_ticks_msec() - start_time
	print("Cave generated in %d ms" % elapsed)


## Render cave data to TileMapLayer
func _render_cave(data: Array) -> void:
	if not tile_layer:
		push_error("TileMapLayer not found! Make sure CaveWorld scene has a TileMapLayer child node.")
		return

	# Clear existing tiles
	tile_layer.clear()

	# Render each tile
	for y in range(cave_generator.cave_height):
		for x in range(cave_generator.cave_width):
			var index = y * cave_generator.cave_width + x
			var tile_type = data[index]

			var atlas_coord: Vector2i

			match tile_type:
				TileType.EMPTY:
					# Don't place a tile (leave as transparent/floor)
					continue
				TileType.WALL:
					atlas_coord = WALL_TILE
				TileType.NUTRIENT:
					# Calculate connected vein sprite based on neighbors
					var bitmask = _calculate_vein_bitmask(Vector2i(x, y), data)
					atlas_coord = Vector2i(VEIN_TILE_START.x + bitmask, 0)

			# Place tile at grid position
			tile_layer.set_cell(Vector2i(x, y), TILESET_SOURCE_ID, atlas_coord)


## Calculate bitmask for vein autotiling based on neighbors
func _calculate_vein_bitmask(grid_pos: Vector2i, data: Array) -> int:
	var bitmask = 0
	var width = cave_generator.cave_width
	var height = cave_generator.cave_height

	# Helper to check if a position has a nutrient vein
	var is_vein = func(pos: Vector2i) -> bool:
		if pos.x < 0 or pos.x >= width or pos.y < 0 or pos.y >= height:
			return false
		var idx = pos.y * width + pos.x
		return data[idx] == TileType.NUTRIENT

	# Check each direction (UP, RIGHT, DOWN, LEFT)
	if is_vein.call(grid_pos + Vector2i(0, -1)):  # UP
		bitmask |= CONNECT_UP
	if is_vein.call(grid_pos + Vector2i(1, 0)):   # RIGHT
		bitmask |= CONNECT_RIGHT
	if is_vein.call(grid_pos + Vector2i(0, 1)):   # DOWN
		bitmask |= CONNECT_DOWN
	if is_vein.call(grid_pos + Vector2i(-1, 0)):  # LEFT
		bitmask |= CONNECT_LEFT

	return bitmask


## Refresh neighboring vein tiles after a vein is destroyed
func _refresh_vein_neighbors(destroyed_pos: Vector2i) -> void:
	# Check all 4 neighboring positions
	var neighbors = [
		destroyed_pos + Vector2i(0, -1),  # UP
		destroyed_pos + Vector2i(1, 0),   # RIGHT
		destroyed_pos + Vector2i(0, 1),   # DOWN
		destroyed_pos + Vector2i(-1, 0)   # LEFT
	]

	for neighbor_pos in neighbors:
		# Skip if out of bounds
		if neighbor_pos.x < 0 or neighbor_pos.x >= cave_generator.cave_width:
			continue
		if neighbor_pos.y < 0 or neighbor_pos.y >= cave_generator.cave_height:
			continue

		# Check if this neighbor is a vein
		var idx = neighbor_pos.y * cave_generator.cave_width + neighbor_pos.x
		if idx >= 0 and idx < cave_data.size() and cave_data[idx] == TileType.NUTRIENT:
			# Recalculate its bitmask and update the tile
			var bitmask = _calculate_vein_bitmask(neighbor_pos, cave_data)
			var atlas_coord = Vector2i(VEIN_TILE_START.x + bitmask, 0)
			tile_layer.set_cell(neighbor_pos, TILESET_SOURCE_ID, atlas_coord)


## Get tile type at world position
func get_tile_at_position(world_pos: Vector2) -> int:
	var map_pos = tile_layer.local_to_map(world_pos)
	var tile_data = tile_layer.get_cell_tile_data(map_pos)

	if tile_data == null:
		return TileType.EMPTY

	var atlas_coord = tile_layer.get_cell_atlas_coords(map_pos)

	if atlas_coord == WALL_TILE:
		return TileType.WALL
	# Check if it's any vein tile (x position 1-16 for the 16 vein variants)
	elif atlas_coord.y == 0 and atlas_coord.x >= VEIN_TILE_START.x and atlas_coord.x <= VEIN_TILE_START.x + 15:
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


## Harvest tile at position (with resource gain and effects)
func harvest_tile_at_position(world_pos: Vector2) -> bool:
	var map_pos = tile_layer.local_to_map(world_pos)
	var tile_type = get_tile_at_position(world_pos)

	# Only nutrient tiles can be harvested
	if tile_type != TileType.NUTRIENT:
		return false

	# Calculate nutrient gain (15-25 per tile)
	var nutrient_gain = randi_range(15, 25)

	# Add resources to mycelium manager
	if mycelium_manager:
		mycelium_manager.add_nutrients(nutrient_gain)
		ExperienceManager.add_xp(float(nutrient_gain))
		print("Gained %d nutrients and XP from harvest!" % nutrient_gain)

	# Spawn destruction particles
	_spawn_destruction_particles(world_pos)

	# Apply screen shake
	_apply_screen_shake()

	# Destroy the tile
	tile_layer.erase_cell(map_pos)

	# Update cave_data to reflect the destroyed tile
	if cave_data.size() > 0:
		var idx = map_pos.y * cave_generator.cave_width + map_pos.x
		if idx >= 0 and idx < cave_data.size():
			cave_data[idx] = TileType.EMPTY

		# Refresh neighboring vein tiles to update their connections
		_refresh_vein_neighbors(map_pos)

	return true


## Spawn particles for tile destruction
func _spawn_destruction_particles(world_pos: Vector2) -> void:
	var particles = GPUParticles2D.new()
	particles.position = world_pos
	particles.amount = 20
	particles.lifetime = 0.8
	particles.one_shot = true
	particles.explosiveness = 1.0

	# Create particle material for rock chunks
	var particle_material = ParticleProcessMaterial.new()
	particle_material.particle_flag_disable_z = true
	particle_material.direction = Vector3(0, -1, 0)
	particle_material.spread = 180.0
	particle_material.initial_velocity_min = 40.0
	particle_material.initial_velocity_max = 80.0
	particle_material.gravity = Vector3(0, 150, 0)
	particle_material.scale_min = 2.0
	particle_material.scale_max = 4.0
	particle_material.color = Color(0.3, 0.3, 0.3, 1.0)  # Grey rock color

	particles.process_material = particle_material
	particles.emitting = true

	add_child(particles)

	# Auto-delete after lifetime
	await get_tree().create_timer(particles.lifetime + 0.2).timeout
	particles.queue_free()


## Apply screen shake effect
func _apply_screen_shake() -> void:
	# Get camera and apply shake
	var camera = get_node("/root/Main/Camera2D")
	if camera and camera.has_method("apply_shake"):
		camera.apply_shake(5.0, 0.2)  # 5 pixel intensity, 0.2 second duration


## Get cave bounds in world coordinates
func get_cave_bounds() -> Rect2:
	var tile_size = tile_layer.tile_set.tile_size if tile_layer.tile_set else Vector2i(16, 16)
	return Rect2(
		Vector2.ZERO,
		Vector2(cave_generator.cave_width * tile_size.x, cave_generator.cave_height * tile_size.y)
	)
