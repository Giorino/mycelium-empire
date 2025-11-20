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
			if data.get("nutrient_generation_rate") > 0:
				total_generated += data.nutrient_generation_rate
				
		if total_generated > 0:
			mycelium_manager.add_nutrients(total_generated)
			# Optional: Show popup text for generation?


func _ready() -> void:
	if not mycelium_manager:
		push_error("BuildingManager: MyceliumManager not found!")

## Check if a building can be placed at the given world position
func can_place_building(world_pos: Vector2, building_data: Resource) -> bool:
	if not mycelium_manager:
		return false
		
	var grid_pos = mycelium_manager.mycelium_layer.local_to_map(world_pos)
	
	# 1. Must be on Mycelium
	if not mycelium_manager.has_mycelium_at(world_pos):
		return false
		
	# 2. Must not already have a building
	if buildings.has(grid_pos):
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
func place_building(world_pos: Vector2, building_data: Resource) -> bool:
	if not can_place_building(world_pos, building_data):
		return false
		
	var grid_pos = mycelium_manager.mycelium_layer.local_to_map(world_pos)
	
	# Deduct cost
	mycelium_manager.add_nutrients(-building_data.nutrient_cost)
	
	# Instantiate building
	var building_instance = building_data.scene.instantiate()
	building_instance.position = mycelium_manager.mycelium_layer.map_to_local(grid_pos)
	add_child(building_instance)
	
	# Track building
	buildings[grid_pos] = building_instance
	building_data_map[grid_pos] = building_data
	
	emit_signal("building_placed", building_instance, grid_pos)
	print("Placed building: %s at %v" % [building_data.name, grid_pos])
	
	_update_storage_capacity()
	
	return true
