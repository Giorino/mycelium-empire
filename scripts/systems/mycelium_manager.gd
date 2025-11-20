class_name MyceliumManager
extends Node2D

## Manages mycelium spread mechanics, growth, and visualization
## Mycelium provides pathways for minions and territorial control

signal mycelium_placed(grid_pos: Vector2i)
signal mycelium_spread(grid_pos: Vector2i)
signal nutrients_changed(current: int, max: int)

@export_group("Growth Parameters")
@export var growth_interval: float = 2.0  # Seconds between growth ticks
@export var spread_chance: float = 0.7    # Probability of spreading to adjacent tile
@export var max_spread_per_tick: int = 3  # Maximum tiles to spread per growth tick

@export_group("Placement Costs")
@export var initial_placement_cost: int = 10  # Nutrients required to place initial mycelium
@export var starting_nutrients: int = 50      # Starting resource amount

@export_group("Visual Settings")
@export var enable_glow: bool = true
@export var glow_energy: float = 0.1 # 1.5
@export var glow_radius: float = 20.0 # 32.0
@export var particle_amount: int = 16

# References
@onready var mycelium_layer: TileMapLayer = $MyceliumLayer
@onready var cave_world: Node = get_parent()

# Tile atlas coordinates - Connected mycelium veins use bitmask autotiling
# Bitmask: UP=1, RIGHT=2, DOWN=4, LEFT=8
const MYCELIUM_TILE_START = Vector2i(0, 0)  # First tile in connected set
const TILESET_SOURCE_ID = 0

# Bitmask values for mycelium connections
const CONNECT_UP = 1
const CONNECT_RIGHT = 2
const CONNECT_DOWN = 4
const CONNECT_LEFT = 8

# Growth tracking
var growth_timer: float = 0.0
var mycelium_tiles: Dictionary = {}  # Vector2i -> growth_stage (0-2)
var active_growth_frontier: Array[Vector2i] = []  # Tiles that can spread

# Resources
var current_nutrients: int = 0
var max_nutrients: int = 0 # Determined by buildings (starts at 0)

# Light pool for performance
var light_pool: Array[PointLight2D] = []
var active_lights: Dictionary = {}  # Vector2i -> PointLight2D


func _ready() -> void:
	current_nutrients = starting_nutrients
	nutrients_changed.emit(current_nutrients, starting_nutrients)
	_initialize_light_pool()
	_apply_glow_shader()


func _process(delta: float) -> void:
	_update_growth(delta)


## Apply pulsing glow shader to mycelium layer
func _apply_glow_shader() -> void:
	if not mycelium_layer:
		return

	# Load shader
	var shader = load("res://resources/shaders/mycelium_glow.gdshader")
	if shader:
		var material = ShaderMaterial.new()
		material.shader = shader
		# Set shader parameters
		material.set_shader_parameter("pulse_speed", 1.5)
		material.set_shader_parameter("pulse_strength", 0.25)
		material.set_shader_parameter("glow_color", Color(0.0, 1.0, 1.0, 1.0))
		material.set_shader_parameter("brightness_boost", 1.8)

		mycelium_layer.material = material
		print("Mycelium glow shader applied!")


## Initialize pool of light nodes for performance
func _initialize_light_pool() -> void:
	# Pre-create 100 lights for pooling
	for i in range(100):
		var light = PointLight2D.new()
		light.enabled = false
		light.texture = _create_light_gradient()
		light.texture_scale = 2.0
		light.energy = glow_energy
		light.color = Color(0.0, 0.8, 1.0)  # Cyan glow
		light.range_layer_max = 2
		add_child(light)
		light_pool.append(light)


## Create a radial gradient texture for lights
func _create_light_gradient() -> GradientTexture2D:
	var gradient = Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))

	var gradient_texture = GradientTexture2D.new()
	gradient_texture.gradient = gradient
	gradient_texture.fill = GradientTexture2D.FILL_RADIAL
	gradient_texture.width = 64
	gradient_texture.height = 64

	return gradient_texture


## Get a light from the pool
func _get_light_from_pool() -> PointLight2D:
	for light in light_pool:
		if not light.enabled:
			return light

	# Pool exhausted, create new light
	var light = PointLight2D.new()
	light.texture = _create_light_gradient()
	light.texture_scale = 2.0
	light.energy = glow_energy
	light.color = Color(0.0, 0.8, 1.0)
	add_child(light)
	light_pool.append(light)
	return light


## Return light to pool
func _return_light_to_pool(light: PointLight2D) -> void:
	light.enabled = false


## Update mycelium growth over time
func _update_growth(delta: float) -> void:
	growth_timer += delta

	if growth_timer >= growth_interval:
		growth_timer = 0.0
		_perform_growth_tick()


## Perform one growth cycle
func _perform_growth_tick() -> void:
	if active_growth_frontier.is_empty():
		return

	var tiles_spread_this_tick = 0
	var new_frontier: Array[Vector2i] = []

	# Shuffle frontier for randomness
	active_growth_frontier.shuffle()

	for tile_pos in active_growth_frontier:
		if tiles_spread_this_tick >= max_spread_per_tick:
			# Keep remaining tiles for next tick
			new_frontier.append(tile_pos)
			continue

		# Try to spread to neighbors
		var neighbors = _get_empty_neighbors(tile_pos)

		if neighbors.is_empty():
			# This tile can't spread anymore
			continue

		# Pick random neighbor to spread to
		neighbors.shuffle()
		for neighbor in neighbors:
			if randf() < spread_chance:
				_place_mycelium_at(neighbor, false)  # Free growth (no cost)
				mycelium_spread.emit(neighbor)
				tiles_spread_this_tick += 1
				break

		# If tile still has potential to spread, keep in frontier
		if not _get_empty_neighbors(tile_pos).is_empty():
			new_frontier.append(tile_pos)

	active_growth_frontier = new_frontier


## Get empty neighbors that can be spread to
func _get_empty_neighbors(grid_pos: Vector2i) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	var directions = [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1)
	]

	for dir in directions:
		var neighbor_pos = grid_pos + dir

		# Check if position is valid and empty
		if _can_place_mycelium_at(neighbor_pos):
			neighbors.append(neighbor_pos)

	return neighbors


## Check if mycelium can be placed at position
func _can_place_mycelium_at(grid_pos: Vector2i) -> bool:
	# Already has mycelium
	if mycelium_tiles.has(grid_pos):
		return false

	# Check if cave tile is empty (not a wall)
	if cave_world:
		var world_pos = mycelium_layer.map_to_local(grid_pos)
		var tile_type = cave_world.get_tile_at_position(world_pos)

		# Can only place on empty tiles
		if tile_type != CaveWorld.TileType.EMPTY:
			return false

	return true


## Place mycelium at grid position (user or growth)
func place_mycelium(world_pos: Vector2, ignore_cost: bool = false) -> bool:
	var grid_pos = mycelium_layer.local_to_map(world_pos)

	# Check if can place
	if not _can_place_mycelium_at(grid_pos):
		return false

	# Check resource cost
	if not ignore_cost:
		if current_nutrients < initial_placement_cost:
			print("Not enough nutrients! Need: %d, Have: %d" % [initial_placement_cost, current_nutrients])
			return false

		# Deduct cost
		current_nutrients -= initial_placement_cost
		nutrients_changed.emit(current_nutrients, starting_nutrients)

	# Place mycelium
	_place_mycelium_at(grid_pos, true)
	mycelium_placed.emit(grid_pos)

	return true


## Internal placement logic
func _place_mycelium_at(grid_pos: Vector2i, with_particles: bool = true) -> void:
	# Add to tracking
	mycelium_tiles[grid_pos] = 0  # Growth stage 0
	active_growth_frontier.append(grid_pos)

	# Calculate connected tile based on neighbors
	var bitmask = _calculate_mycelium_bitmask(grid_pos)
	var atlas_coord = Vector2i(MYCELIUM_TILE_START.x + bitmask, 0)

	# Place tile
	mycelium_layer.set_cell(grid_pos, TILESET_SOURCE_ID, atlas_coord)

	# Update neighboring mycelium tiles to connect to this new one
	_refresh_mycelium_neighbors(grid_pos)

	# Add glow light
	if enable_glow:
		_add_light_at(grid_pos)

	# Spawn particles
	if with_particles:
		_spawn_placement_particles(grid_pos)


## Add dynamic light at tile position
func _add_light_at(grid_pos: Vector2i) -> void:
	var light = _get_light_from_pool()
	light.position = mycelium_layer.map_to_local(grid_pos)
	light.enabled = true
	active_lights[grid_pos] = light


## Remove light at position
func _remove_light_at(grid_pos: Vector2i) -> void:
	if active_lights.has(grid_pos):
		var light = active_lights[grid_pos]
		_return_light_to_pool(light)
		active_lights.erase(grid_pos)


## Calculate bitmask for mycelium autotiling based on neighbors
func _calculate_mycelium_bitmask(grid_pos: Vector2i) -> int:
	var bitmask = 0

	# Helper to check if a position has mycelium
	var has_mycelium = func(pos: Vector2i) -> bool:
		return mycelium_tiles.has(pos)

	# Check each direction (UP, RIGHT, DOWN, LEFT)
	if has_mycelium.call(grid_pos + Vector2i(0, -1)):  # UP
		bitmask |= CONNECT_UP
	if has_mycelium.call(grid_pos + Vector2i(1, 0)):   # RIGHT
		bitmask |= CONNECT_RIGHT
	if has_mycelium.call(grid_pos + Vector2i(0, 1)):   # DOWN
		bitmask |= CONNECT_DOWN
	if has_mycelium.call(grid_pos + Vector2i(-1, 0)):  # LEFT
		bitmask |= CONNECT_LEFT

	return bitmask


## Refresh neighboring mycelium tiles after a new one is placed/removed
func _refresh_mycelium_neighbors(center_pos: Vector2i) -> void:
	# Check all 4 neighboring positions
	var neighbors = [
		center_pos + Vector2i(0, -1),  # UP
		center_pos + Vector2i(1, 0),   # RIGHT
		center_pos + Vector2i(0, 1),   # DOWN
		center_pos + Vector2i(-1, 0)   # LEFT
	]

	for neighbor_pos in neighbors:
		# Check if this neighbor has mycelium
		if mycelium_tiles.has(neighbor_pos):
			# Recalculate its bitmask and update the tile
			var bitmask = _calculate_mycelium_bitmask(neighbor_pos)
			var atlas_coord = Vector2i(MYCELIUM_TILE_START.x + bitmask, 0)
			mycelium_layer.set_cell(neighbor_pos, TILESET_SOURCE_ID, atlas_coord)


## Set starting nutrients to default
func set_starting_nutrients_to_default() -> void:
	current_nutrients = starting_nutrients
	nutrients_changed.emit(current_nutrients, starting_nutrients)


## Spawn particles for mycelium placement (growth burst effect)
func _spawn_placement_particles(grid_pos: Vector2i) -> void:
	var particles = GPUParticles2D.new()
	particles.position = mycelium_layer.map_to_local(grid_pos)
	particles.amount = 32  # More particles for organic feel
	particles.lifetime = 1.5  # Longer-lasting spore effect
	particles.one_shot = true
	particles.explosiveness = 0.5  # Less explosive, more organic spread

	# Create particle material for fuzzy spore effect
	var particle_material = ParticleProcessMaterial.new()
	particle_material.particle_flag_disable_z = true
	particle_material.direction = Vector3(0, -1, 0)  # Float upward
	particle_material.spread = 180.0  # Spread in all directions
	particle_material.initial_velocity_min = 10.0  # Slower, gentler movement
	particle_material.initial_velocity_max = 30.0
	particle_material.gravity = Vector3(0, -15, 0)  # Float upward gently (negative gravity)
	particle_material.angular_velocity_min = -45.0  # Gentle rotation
	particle_material.angular_velocity_max = 45.0
	particle_material.scale_min = 0.5  # Small fuzzy particles
	particle_material.scale_max = 2.5
	particle_material.color = Color(0.0, 1.0, 1.0, 0.8)  # Cyan with slight transparency

	# Add variation with color ramp for fade out
	var gradient = Gradient.new()
	gradient.set_color(0, Color(0.5, 1.0, 1.0, 1.0))  # Bright cyan at start
	gradient.set_color(1, Color(0.0, 0.8, 1.0, 0.0))  # Fade to transparent
	particle_material.color_ramp = gradient

	particles.process_material = particle_material
	particles.emitting = true

	add_child(particles)

	# Auto-delete after lifetime
	await get_tree().create_timer(particles.lifetime + 0.5).timeout
	particles.queue_free()


## Remove mycelium at position (for destruction)
func remove_mycelium_at(world_pos: Vector2) -> bool:
	var grid_pos = mycelium_layer.local_to_map(world_pos)

	if not mycelium_tiles.has(grid_pos):
		return false

	# Remove from tracking
	mycelium_tiles.erase(grid_pos)
	active_growth_frontier.erase(grid_pos)

	# Remove tile
	mycelium_layer.erase_cell(grid_pos)

	# Remove light
	_remove_light_at(grid_pos)

	# Update neighboring tiles to disconnect from this removed tile
	_refresh_mycelium_neighbors(grid_pos)

	return true


## Clear all mycelium from the map
func clear_all() -> void:
	# Clear visual tiles
	mycelium_layer.clear()

	# Clear tracking data
	mycelium_tiles.clear()
	active_growth_frontier.clear()

	# Return all active lights to the pool by iterating over a copy of the keys.
	# This prevents issues with modifying the dictionary while iterating over it.
	var light_positions = active_lights.keys()
	for grid_pos in light_positions:
		_remove_light_at(grid_pos)
	
	active_lights.clear()


## Check if position has mycelium
func has_mycelium_at(world_pos: Vector2) -> bool:
	var grid_pos = mycelium_layer.local_to_map(world_pos)
	return mycelium_tiles.has(grid_pos)


## Get total mycelium coverage
func get_mycelium_count() -> int:
	return mycelium_tiles.size()


## Add nutrients (from harvesting, events, etc.)
func add_nutrients(amount: int) -> void:
	current_nutrients += amount
	
	# Cap at max_nutrients (unless max is 0, which shouldn't happen after game start)
	if max_nutrients > 0 and current_nutrients > max_nutrients:
		current_nutrients = max_nutrients
		
	nutrients_changed.emit(current_nutrients, max_nutrients)

## Update max nutrients
func update_max_nutrients(new_max: int) -> void:
	max_nutrients = new_max
	# Clamp current if it exceeds new max
	if current_nutrients > max_nutrients:
		current_nutrients = max_nutrients
	nutrients_changed.emit(current_nutrients, max_nutrients)
