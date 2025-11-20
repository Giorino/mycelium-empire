extends Node

## Handles player input for mycelium placement and interaction

# Node references
@onready var mycelium_manager: Node = get_node("../CaveWorld/MyceliumManager")
@onready var cave_world: Node = get_node("../CaveWorld")
@onready var camera: Camera2D = get_node("../Camera2D")

# Input state
var mouse_world_pos: Vector2


func _ready() -> void:
	if not mycelium_manager:
		push_error("PlayerInput: MyceliumManager not found!")
	if not camera:
		push_error("PlayerInput: Camera2D not found!")


func _process(_delta: float) -> void:
	_update_mouse_position()


func _input(event: InputEvent) -> void:
	# Handle mouse clicks
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_handle_mycelium_placement()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_handle_harvesting()


## Update mouse world position
func _update_mouse_position() -> void:
	if camera:
		mouse_world_pos = camera.get_global_mouse_position()


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
