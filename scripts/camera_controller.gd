extends Camera2D

## Simple camera controller for testing
## WASD/Arrow keys to pan, Mouse wheel to zoom, R to regenerate cave

@export var pan_speed: float = 300.0
@export var zoom_speed: float = 0.1
@export var min_zoom: float = 0.25
@export var max_zoom: float = 4.0

# Screen shake variables
var shake_intensity: float = 0.0
var shake_duration: float = 0.0
var shake_timer: float = 0.0
var original_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	# Start with a nice zoom level to see the cave
	zoom = Vector2(1.5, 1.5)
	original_offset = offset
	
	# Center on cave after a short delay to ensure generation is complete
	await get_tree().process_frame
	center_on_cave()


## Center the camera on the cave
func center_on_cave() -> void:
	var cave_world = get_parent().get_node_or_null("CaveWorld")
	if cave_world and cave_world.has_method("get_cave_bounds"):
		var bounds = cave_world.get_cave_bounds()
		position = bounds.get_center()
		print("Camera centered on cave at: ", position)



func _process(delta: float) -> void:
	_handle_panning(delta)
	_handle_zoom()
	_handle_regeneration()
	_handle_screen_shake(delta)


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
			center_on_cave()
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


## Handle screen shake animation
func _handle_screen_shake(delta: float) -> void:
	if shake_timer > 0:
		shake_timer -= delta

		# Apply random offset based on intensity
		var shake_offset = Vector2(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity)
		)
		offset = original_offset + shake_offset
	else:
		# Reset to original offset when shake ends
		if shake_intensity > 0:
			offset = original_offset
			shake_intensity = 0.0


## Apply screen shake effect
func apply_shake(intensity: float, duration: float) -> void:
	shake_intensity = intensity
	shake_duration = duration
	shake_timer = duration
