class_name BuildingManager
extends Node2D

## Manages the placement and lifecycle of organic structures

signal building_placed(building_instance: Node2D, grid_pos: Vector2i)

# References
@onready var mycelium_manager: Node = get_node("../MyceliumManager")
@onready var cave_world: Node = get_parent()

# State
var buildings: Dictionary = {} # Vector2i -> Node2D
var building_data_map: Dictionary = {} # Vector2i -> Resource (BuildingData)
var generation_timer: float = 0.0
var generation_interval: float = 1.0 # Generate every second

func _process(delta: float) -> void:
	_handle_resource_generation(delta)

func _handle_resource_generation(delta: float) -> void:
	if not mycelium_manager:
		return
		
	generation_timer += delta
	if generation_timer >= generation_interval:
		generation_timer = 0.0
		
		var total_generated = 0
		for grid_pos in building_data_map:
			var data = building_data_map[grid_pos]
			
			# Skip buildings that manage their own generation (e.g., SporePod with workers)
			var building_instance = buildings.get(grid_pos)
			if building_instance and building_instance.has_method("has_worker"):
				# This building manages its own generation
				continue
			
			if data.get("nutrient_generation_rate") > 0:
				total_generated += data.nutrient_generation_rate
				
		if total_generated > 0:
			mycelium_manager.add_nutrients(total_generated)
			# Optional: Show popup text for generation?


func _ready() -> void:
	if not mycelium_manager:
		push_error("BuildingManager: MyceliumManager not found!")

## Get all grid positions occupied by a building
## Uses center-tile placement: for a 3x3 building, center is clicked position
func _get_occupied_tiles(center_pos: Vector2i, grid_size: Vector2i) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	var half_x = int(grid_size.x / 2)
	var half_y = int(grid_size.y / 2)
	
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var offset_x = x - half_x
			var offset_y = y - half_y
			tiles.append(center_pos + Vector2i(offset_x, offset_y))
	
	return tiles



## Check if a building can be placed at the given world position
func can_place_building(world_pos: Vector2, building_data: BuildingData) -> bool:
	if not mycelium_manager:
		return false
		
	var center_grid_pos = mycelium_manager.mycelium_layer.local_to_map(world_pos)
	
	# Get all tiles this building will occupy
	var occupied_tiles = _get_occupied_tiles(center_grid_pos, building_data.grid_size)
	
	# 1. All tiles must be on Mycelium
	for tile_pos in occupied_tiles:
		var tile_world_pos = mycelium_manager.mycelium_layer.map_to_local(tile_pos)
		if not mycelium_manager.has_mycelium_at(tile_world_pos):
			return false
	
	# 2. All tiles must not already have a building
	for tile_pos in occupied_tiles:
		if buildings.has(tile_pos):
			return false
		
	# 3. Must have enough nutrients
	if mycelium_manager.current_nutrients < building_data.nutrient_cost:
		return false
		
	# 4. Check build limit
	if building_data.build_limit > 0:
		var count = 0
		for pos in building_data_map:
			if building_data_map[pos].id == building_data.id:
				count += 1
		
		if count >= building_data.build_limit:
			print("Build limit reached for %s" % building_data.name)
			return false
			
	return true


## Calculate total storage capacity from all buildings
func _update_storage_capacity() -> void:
	if not mycelium_manager:
		return
		
	var total_storage = 0
	for pos in building_data_map:
		var data = building_data_map[pos]
		if data.get("storage_capacity") > 0:
			total_storage += data.storage_capacity
			
	# If no storage buildings, keep a small base amount (e.g. 50) or 0?
	# Let's say base is 50.
	if total_storage == 0:
		total_storage = 50
		
	if mycelium_manager.has_method("update_max_nutrients"):
		mycelium_manager.update_max_nutrients(total_storage)

## Place a building at the given world position
func place_building(world_pos: Vector2, building_data: BuildingData) -> bool:
	if not can_place_building(world_pos, building_data):
		return false
		
	var center_grid_pos = mycelium_manager.mycelium_layer.local_to_map(world_pos)
	
	# Deduct cost
	mycelium_manager.add_nutrients(-building_data.nutrient_cost)
	
	# Instantiate building at center position
	var building_instance = building_data.scene.instantiate()
	building_instance.position = mycelium_manager.mycelium_layer.map_to_local(center_grid_pos)
	add_child(building_instance)
	
	# Get all tiles this building occupies
	var occupied_tiles = _get_occupied_tiles(center_grid_pos, building_data.grid_size)
	
	# Track building at ALL occupied tiles (for collision detection)
	for tile_pos in occupied_tiles:
		buildings[tile_pos] = building_instance
	
	# Store building data only at center position
	building_data_map[center_grid_pos] = building_data
	
	emit_signal("building_placed", building_instance, center_grid_pos)
	print("Placed building: %s at %v (size: %v, occupying %d tiles)" % [building_data.name, center_grid_pos, building_data.grid_size, occupied_tiles.size()])
	
	_update_storage_capacity()
	
	return true



## Get building at world position
func get_building_at(world_pos: Vector2) -> Node2D:
	if not mycelium_manager:
		return null
		
	var grid_pos = mycelium_manager.mycelium_layer.local_to_map(world_pos)
	return buildings.get(grid_pos)
