extends Camera2D

## Simple camera controller for testing
## WASD/Arrow keys to pan, Mouse wheel to zoom, R to regenerate cave

@export var pan_speed: float = 300.0
@export var zoom_speed: float = 0.1
@export var min_zoom: float = 0.25
@export var max_zoom: float = 4.0

func _ready() -> void:
	# Start with a nice zoom level to see the cave
	zoom = Vector2(1.5, 1.5)


func _process(delta: float) -> void:
	_handle_panning(delta)
	_handle_zoom()
	_handle_regeneration()


func _handle_panning(delta: float) -> void:
	var movement = Vector2.ZERO

	# WASD or Arrow keys
	if Input.is_action_pressed("ui_right"):
		movement.x += 1
	if Input.is_action_pressed("ui_left"):
		movement.x -= 1
	if Input.is_action_pressed("ui_down"):
		movement.y += 1
	if Input.is_action_pressed("ui_up"):
		movement.y -= 1

	if movement.length() > 0:
		movement = movement.normalized()
		position += movement * pan_speed * delta / zoom.x


func _handle_zoom() -> void:
	var zoom_change = 0.0

	if Input.is_action_just_released("ui_page_up"):  # Mouse wheel up
		zoom_change = zoom_speed
	elif Input.is_action_just_released("ui_page_down"):  # Mouse wheel down
		zoom_change = -zoom_speed

	if zoom_change != 0.0:
		var new_zoom = clamp(zoom.x + zoom_change, min_zoom, max_zoom)
		zoom = Vector2(new_zoom, new_zoom)


func _handle_regeneration() -> void:
	# Press R to regenerate the cave
	if Input.is_key_pressed(KEY_R):
		var cave_world = get_parent().get_node("CaveWorld")
		if cave_world and cave_world.has_method("generate_new_cave"):
			cave_world.generate_new_cave()
			print("Cave regenerated! (Press R to generate again)")


func _input(event: InputEvent) -> void:
	# Handle mouse wheel zoom
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			var new_zoom = clamp(zoom.x + zoom_speed, min_zoom, max_zoom)
			zoom = Vector2(new_zoom, new_zoom)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			var new_zoom = clamp(zoom.x - zoom_speed, min_zoom, max_zoom)
			zoom = Vector2(new_zoom, new_zoom)
