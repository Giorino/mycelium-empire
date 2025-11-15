class_name CaveGenerator
extends Node

## Procedural cave generator using cellular automata and FastNoiseLite
## Generates destructible terrain with embedded nutrient veins

# Tile types
enum TileType {
	EMPTY,      # Air/floor
	WALL,       # Solid rock
	NUTRIENT    # Harvestable nutrient vein
}

# Generation parameters
@export_group("Cave Dimensions")
@export var cave_width: int = 100
@export var cave_height: int = 60

@export_group("Cellular Automata")
@export_range(0.0, 1.0) var initial_wall_probability: float = 0.45
@export var smoothing_iterations: int = 5
@export var wall_survival_threshold: int = 4  # Walls survive with >= this many wall neighbors
@export var wall_birth_threshold: int = 5      # Empty tiles become walls with >= this many wall neighbors

@export_group("Biome Variation")
@export var use_noise_overlay: bool = true
@export var noise_influence: float = 0.3  # How much noise affects cave shape
@export var noise_scale: float = 0.05     # FastNoiseLite frequency

@export_group("Nutrient Veins")
@export_range(0.0, 1.0) var nutrient_vein_density: float = 0.15  # Percentage of walls that become nutrient veins
@export var nutrient_vein_cluster_size: int = 3  # Average cluster size

@export_group("Strategic Features")
@export var ensure_connectivity: bool = true  # Remove isolated wall regions
@export var min_open_area_size: int = 20      # Minimum connected floor space

# Internal data
var cave_data: Array[TileType] = []
var noise: FastNoiseLite

## Generate a new cave and return the tile data
func generate() -> Array[TileType]:
	_initialize_noise()
	_initialize_cave_data()
	_apply_cellular_automata()

	if ensure_connectivity:
		_ensure_connected_cave()

	_place_nutrient_veins()

	return cave_data


## Initialize FastNoiseLite for biome variation
func _initialize_noise() -> void:
	noise = FastNoiseLite.new()
	noise.seed = randi()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = noise_scale
	noise.fractal_octaves = 3


## Create initial random cave layout
func _initialize_cave_data() -> void:
	cave_data.clear()
	cave_data.resize(cave_width * cave_height)

	for y in range(cave_height):
		for x in range(cave_width):
			var is_border = x == 0 or x == cave_width - 1 or y == 0 or y == cave_height - 1

			if is_border:
				# Force borders to be walls
				_set_tile(x, y, TileType.WALL)
			else:
				# Random initial distribution
				var noise_value = 0.0
				if use_noise_overlay:
					noise_value = noise.get_noise_2d(x, y) * noise_influence

				var wall_chance = initial_wall_probability + noise_value

				if randf() < wall_chance:
					_set_tile(x, y, TileType.WALL)
				else:
					_set_tile(x, y, TileType.EMPTY)


## Apply cellular automata smoothing iterations
func _apply_cellular_automata() -> void:
	for iteration in range(smoothing_iterations):
		var new_data: Array[TileType] = cave_data.duplicate()

		for y in range(1, cave_height - 1):
			for x in range(1, cave_width - 1):
				var wall_count = _count_wall_neighbors(x, y)
				var current_tile = _get_tile(x, y)

				# Apply cellular automata rules
				if current_tile == TileType.WALL:
					if wall_count < wall_survival_threshold:
						new_data[_index(x, y)] = TileType.EMPTY
				else:
					if wall_count >= wall_birth_threshold:
						new_data[_index(x, y)] = TileType.WALL

		cave_data = new_data


## Count wall neighbors in 3x3 grid around position
func _count_wall_neighbors(x: int, y: int) -> int:
	var count = 0

	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue

			var nx = x + dx
			var ny = y + dy

			if _is_valid_position(nx, ny):
				if _get_tile(nx, ny) == TileType.WALL:
					count += 1
			else:
				# Count out-of-bounds as walls
				count += 1

	return count


## Ensure cave has one large connected region (flood fill)
func _ensure_connected_cave() -> void:
	# Find largest open area using flood fill
	var visited: Array[bool] = []
	visited.resize(cave_width * cave_height)
	visited.fill(false)

	var largest_region_size = 0
	var largest_region_tiles: Array[Vector2i] = []

	# Find all regions
	for y in range(cave_height):
		for x in range(cave_width):
			if _get_tile(x, y) == TileType.EMPTY and not visited[_index(x, y)]:
				var region = _flood_fill_region(x, y, visited)

				if region.size() > largest_region_size:
					largest_region_size = region.size()
					largest_region_tiles = region

	# Fill in all regions except the largest
	for y in range(cave_height):
		for x in range(cave_width):
			var pos = Vector2i(x, y)
			if _get_tile(x, y) == TileType.EMPTY and pos not in largest_region_tiles:
				_set_tile(x, y, TileType.WALL)


## Flood fill to find connected region
func _flood_fill_region(start_x: int, start_y: int, visited: Array[bool]) -> Array[Vector2i]:
	var region: Array[Vector2i] = []
	var queue: Array[Vector2i] = [Vector2i(start_x, start_y)]
	visited[_index(start_x, start_y)] = true

	while queue.size() > 0:
		var pos = queue.pop_front()
		region.append(pos)

		# Check 4-directional neighbors
		var neighbors = [
			Vector2i(pos.x + 1, pos.y),
			Vector2i(pos.x - 1, pos.y),
			Vector2i(pos.x, pos.y + 1),
			Vector2i(pos.x, pos.y - 1)
		]

		for neighbor in neighbors:
			if _is_valid_position(neighbor.x, neighbor.y):
				var idx = _index(neighbor.x, neighbor.y)
				if _get_tile(neighbor.x, neighbor.y) == TileType.EMPTY and not visited[idx]:
					visited[idx] = true
					queue.append(neighbor)

	return region


## Place nutrient veins in wall tiles with clustering
func _place_nutrient_veins() -> void:
	var wall_positions: Array[Vector2i] = []

	# Collect all wall positions (excluding borders)
	for y in range(1, cave_height - 1):
		for x in range(1, cave_width - 1):
			if _get_tile(x, y) == TileType.WALL:
				# Prefer walls adjacent to open space (more accessible)
				if _has_adjacent_empty(x, y):
					wall_positions.append(Vector2i(x, y))

	# Place nutrient vein clusters
	var target_vein_count = int(wall_positions.size() * nutrient_vein_density)
	var placed_veins = 0

	wall_positions.shuffle()

	for wall_pos in wall_positions:
		if placed_veins >= target_vein_count:
			break

		if _get_tile(wall_pos.x, wall_pos.y) == TileType.WALL:
			# Create a cluster
			var cluster_positions = _get_cluster_positions(wall_pos, nutrient_vein_cluster_size)

			for cluster_pos in cluster_positions:
				if _get_tile(cluster_pos.x, cluster_pos.y) == TileType.WALL:
					_set_tile(cluster_pos.x, cluster_pos.y, TileType.NUTRIENT)
					placed_veins += 1

					if placed_veins >= target_vein_count:
						break


## Get positions for a nutrient vein cluster
func _get_cluster_positions(center: Vector2i, max_size: int) -> Array[Vector2i]:
	var positions: Array[Vector2i] = [center]
	var cluster_size = randi_range(1, max_size)

	for i in range(cluster_size - 1):
		# Pick a random position from existing cluster and grow adjacent
		var base_pos = positions[randi() % positions.size()]

		var neighbors = [
			Vector2i(base_pos.x + 1, base_pos.y),
			Vector2i(base_pos.x - 1, base_pos.y),
			Vector2i(base_pos.x, base_pos.y + 1),
			Vector2i(base_pos.x, base_pos.y - 1)
		]
		neighbors.shuffle()

		for neighbor in neighbors:
			if _is_valid_position(neighbor.x, neighbor.y) and neighbor not in positions:
				positions.append(neighbor)
				break

	return positions


## Check if position has adjacent empty tile
func _has_adjacent_empty(x: int, y: int) -> bool:
	var neighbors = [
		Vector2i(x + 1, y),
		Vector2i(x - 1, y),
		Vector2i(x, y + 1),
		Vector2i(x, y - 1)
	]

	for neighbor in neighbors:
		if _is_valid_position(neighbor.x, neighbor.y):
			if _get_tile(neighbor.x, neighbor.y) == TileType.EMPTY:
				return true

	return false


## Helper: Get tile at position
func _get_tile(x: int, y: int) -> TileType:
	return cave_data[_index(x, y)]


## Helper: Set tile at position
func _set_tile(x: int, y: int, tile: TileType) -> void:
	cave_data[_index(x, y)] = tile


## Helper: Convert 2D coordinates to 1D array index
func _index(x: int, y: int) -> int:
	return y * cave_width + x


## Helper: Check if position is within cave bounds
func _is_valid_position(x: int, y: int) -> bool:
	return x >= 0 and x < cave_width and y >= 0 and y < cave_height
