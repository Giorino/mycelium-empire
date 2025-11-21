extends Node

## Handles player input for mycelium placement and interaction

# Node references
@onready var mycelium_manager: Node = get_node("../CaveWorld/MyceliumManager")
@onready var cave_world: Node = get_node("../CaveWorld")
@onready var camera: Camera2D = get_node("../Camera2D")

# Input state
var mouse_world_pos: Vector2

# Building state
var is_build_mode: bool = false
var selected_building: BuildingData = load("res://resources/buildings/spore_pod.tres")
var mother_egg_resource: BuildingData = load("res://resources/buildings/mother_egg.tres")
var defense_tower_resource: BuildingData = load("res://resources/buildings/defense_tower.tres")
var spore_pod_resource: BuildingData = load("res://resources/buildings/spore_pod.tres")

# Game State
var is_game_started: bool = false

@onready var building_manager: Node = get_node("../CaveWorld/BuildingManager")
@onready var game_ui: Control = get_node("../CanvasLayer/UI")


func _ready() -> void:
	if not mycelium_manager:
		push_error("PlayerInput: MyceliumManager not found!")
	if not camera:
		push_error("PlayerInput: Camera2D not found!")
		
	# Connect to GameUI for building selection
	if game_ui:
		if game_ui.has_signal("building_selected_from_menu"):
			game_ui.building_selected_from_menu.connect(_on_building_selected_from_menu)
		
	# Start game in "Place Mother Egg" mode
	_start_game_placement()

func _start_game_placement() -> void:
	print("GAME START: Place your Mother Egg!")
	is_build_mode = true
	selected_building = mother_egg_resource
	is_game_started = false # Will be set to true after egg placement


func _process(_delta: float) -> void:
	_update_mouse_position()


func _unhandled_input(event: InputEvent) -> void:
	# Toggle build menu
	if event is InputEventKey and event.pressed and event.keycode == KEY_B:
		if game_ui and game_ui.has_method("toggle_build_menu"):
			game_ui.toggle_build_menu()
			# If we are opening the menu, we might want to exit build mode until a selection is made?
			# For now, let's just toggle the UI.
		
	# Handle mouse clicks
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if is_build_mode:
				_handle_building_placement()
			else:
				_handle_selection()
			# Direct mycelium placement removed as per design change
			# else:
			# 	_handle_mycelium_placement()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			# Cancel build mode or selection
			if is_build_mode:
				is_build_mode = false
				print("Build mode cancelled")
			else:
				_clear_selection()
			
			_handle_harvesting()

	# Debug shortcuts
	if event is InputEventKey and event.pressed and event.keycode == KEY_L:
		print("Debug: Adding 100 XP")
		ExperienceManager.add_xp(100.0)

## Handle selection of buildings
func _handle_selection() -> void:
	if not building_manager:
		return

	var building = building_manager.get_building_at(mouse_world_pos)
	if building:
		print("Selected building: %s" % building.name)
		if building is MotherEgg:
			print("Selected Mother Egg!")
			if game_ui and game_ui.has_method("show_egg_actions"):
				game_ui.show_egg_actions(building)
		# Could add else blocks here for other building types
	else:
		# print("No building selected at %v" % mouse_world_pos) # Too spammy?
		_clear_selection()

func _clear_selection() -> void:
	if game_ui and game_ui.has_method("clear_selection"):
		game_ui.clear_selection()

## Handle building placement
func _handle_building_placement() -> void:
	if not building_manager:
		return
		
	# Special check for Mother Egg (Game Start)
	if not is_game_started:
		if selected_building.id == "mother_egg":
			# Mother Egg can be placed anywhere (doesn't need Mycelium)
			# But we need to hack the BuildingManager or MyceliumManager to allow it?
			# Actually, let's just place some initial mycelium UNDER the egg automatically.
			
			# 1. Place Mycelium at this spot (free)
			if mycelium_manager:
				mycelium_manager.place_mycelium(mouse_world_pos, true) # Ignore cost for Mother Egg base
				# Force place? MyceliumManager checks cost. 
				# Let's give player some starting nutrients to cover it, or make a force function.
				# For now, let's assume starting nutrients cover it.
			
			# 2. Place Egg
			var egg_placed = building_manager.place_building(mouse_world_pos, selected_building)
			
			if egg_placed:
				print("Mother Egg placed! Game Started.")
				is_game_started = true
				is_build_mode = false # Exit build mode
				selected_building = load("res://resources/buildings/spore_pod.tres") # Reset to default
				_update_blueprint() # Clear blueprint
		return

	var success = building_manager.place_building(mouse_world_pos, selected_building)
	
	if success:
		print("Placed building!")
		# Optional: Exit build mode after placement?
		# is_build_mode = false
		# selected_building = null
	else:
		print("Cannot place building here (Need Mycelium + Nutrients + Limit Check)")


## Update mouse world position
func _update_mouse_position() -> void:
	if camera:
		mouse_world_pos = camera.get_global_mouse_position()
	
	_update_blueprint()


## Handle mycelium placement on click
func _handle_mycelium_placement() -> void:
	if not mycelium_manager:
		return

	var success = mycelium_manager.place_mycelium(mouse_world_pos)

	if success:
		print("Mycelium placed at: %v" % mouse_world_pos)
	else:
		print("Cannot place mycelium at: %v" % mouse_world_pos)


## Handle harvesting nutrient tiles
func _handle_harvesting() -> void:
	if not cave_world:
		return

	var success = cave_world.harvest_tile_at_position(mouse_world_pos)

	if success:
		print("Harvested tile at: %v" % mouse_world_pos)
	else:
		print("Nothing to harvest at: %v" % mouse_world_pos)

func _on_building_selected_from_menu(building_data: BuildingData) -> void:
	if selected_building != building_data:
		# Clear existing blueprint to force recreation
		if blueprint_instance:
			blueprint_instance.queue_free()
			blueprint_instance = null
			
	selected_building = building_data
	is_build_mode = true
	print("Selected from menu: %s" % building_data.name)

# --- Blueprint Logic ---
var blueprint_instance: Node2D = null

func _update_blueprint() -> void:
	# 1. Check if we should show blueprint
	if not is_build_mode or not selected_building:
		if blueprint_instance:
			blueprint_instance.queue_free()
			blueprint_instance = null
		return

	# 2. Create blueprint if needed
	if not blueprint_instance:
		if selected_building.scene:
			blueprint_instance = selected_building.scene.instantiate()
			add_child(blueprint_instance)
			# Make it semi-transparent
			blueprint_instance.modulate.a = 0.5
			# Disable processing/physics for the ghost
			blueprint_instance.process_mode = Node.PROCESS_MODE_DISABLED
	
	# 3. Check if the blueprint matches the selected building (in case we switched)
	# (This is a bit tricky if we don't store the source. For now, assume recreation on switch is handled by queue_free elsewhere or simple check)
	# A simple way is to check a custom property or just free it if we switch. 
	# For now, let's just trust it or re-instantiate if needed.
	# Ideally, we'd store `current_blueprint_id`
	
	if blueprint_instance:
		# 4. Snap to grid
		if mycelium_manager:
			var grid_pos = mycelium_manager.mycelium_layer.local_to_map(mouse_world_pos)
			blueprint_instance.position = mycelium_manager.mycelium_layer.map_to_local(grid_pos)
		else:
			blueprint_instance.position = mouse_world_pos
			
		# 5. Check validity
		var is_valid = false
		if building_manager:
			# Special case for Mother Egg
			if not is_game_started and selected_building.id == "mother_egg":
				is_valid = true # Can place anywhere initially (mostly)
			else:
				is_valid = building_manager.can_place_building(mouse_world_pos, selected_building)
		
		# 6. Update Visuals
		if is_valid:
			blueprint_instance.modulate = Color(0.5, 1.0, 0.5, 0.6) # Greenish
		else:
			blueprint_instance.modulate = Color(1.0, 0.5, 0.5, 0.6) # Reddish
