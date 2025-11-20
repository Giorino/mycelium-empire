class_name BuildingManager
extends Node2D

## Manages the placement and lifecycle of organic structures

signal building_placed(building_instance: Node2D, grid_pos: Vector2i)

# References
@onready var mycelium_manager: Node = get_node("../MyceliumManager")
@onready var cave_world: Node = get_parent()

# State
var buildings: Dictionary = {} # Vector2i -> Node2D

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
		
	return true

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
	
	emit_signal("building_placed", building_instance, grid_pos)
	print("Placed building: %s at %v" % [building_data.name, grid_pos])
	
	return true
