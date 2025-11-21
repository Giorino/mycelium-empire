class_name Minion
extends CharacterBody2D

## Autonomous fungal creature that harvests nutrients and maintains the colony
## Uses FSM (Finite State Machine) for needs-driven behavior

signal nutrient_harvested(amount: int)
signal minion_died
signal state_changed(new_state: String)

# States for FSM
enum State {
	IDLE,
	SEEKING_NUTRIENT,
	MOVING_TO_TARGET,
	HARVESTING,
	STARVING
}

@export_group("Movement")
@export var move_speed: float = 60.0
@export var wander_radius: float = 100.0

@export_group("Needs")
@export var max_hunger: float = 100.0
@export var hunger_rate: float = 1.0  # Hunger per second
@export var starvation_threshold: float = 20.0
@export var harvest_duration: float = 10.0  # Seconds to harvest one tile

@export_group("Behavior")
@export var sight_range: float = 200.0
@export var nutrient_per_harvest: int = 20  # How much colony gains per harvest
@export var upkeep_interval: float = 8.0  # Seconds between upkeep consumption
@export var upkeep_cost: int = 10  # Nutrients consumed per upkeep tick

@export_group("Combat")
@export var max_health: int = 50

# State
var current_state: State = State.IDLE
var hunger: float = 0.0
var is_alive: bool = true
var current_health: int = 50

# Targeting
var target_position: Vector2 = Vector2.ZERO
var target_nutrient_tile: Vector2i = Vector2i(-999, -999)
var harvest_timer: float = 0.0
var upkeep_timer: float = 0.0

# References
var cave_world: Node = null
var mycelium_manager: Node = null
var path: Array[Vector2] = []
var path_index: int = 0

# Visuals
@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer if has_node("AnimationPlayer") else null
@onready var health_bar: Node2D = $HealthBar if has_node("HealthBar") else null

# Animation state
var idle_bounce_time: float = 0.0
var move_animation_time: float = 0.0
var base_scale: Vector2 = Vector2.ONE
var current_tween: Tween = null


func _ready() -> void:
	# Find world references - traverse up to find CaveWorld
	var parent = get_parent()
	while parent:
		if parent.name == "MinionManager":
			cave_world = parent.get_parent()
			if cave_world and cave_world.has_node("MyceliumManager"):
				mycelium_manager = cave_world.get_node("MyceliumManager")
			break
		parent = parent.get_parent()

	if not cave_world:
		push_error("Minion: Could not find CaveWorld!")
	if not mycelium_manager:
		push_error("Minion: Could not find MyceliumManager!")

	print("Minion ready - CaveWorld: %s, MyceliumManager: %s" % [cave_world != null, mycelium_manager != null])

	# Initialize health
	current_health = max_health
	if health_bar and health_bar.has_method("setup"):
		health_bar.setup(current_health, max_health)

	# Spawn animation - pop in!
	_play_spawn_animation()

	# Start in idle state
	_change_state(State.IDLE)


func _process(delta: float) -> void:
	if not is_alive:
		return

	# Update needs
	_update_hunger(delta)

	# Run state machine
	_update_state(delta)

	# Visual updates
	_update_visuals(delta)


func _physics_process(_delta: float) -> void:
	if not is_alive:
		return

	# Move character using Godot 4's move_and_slide (no parameters)
	move_and_slide()


## Update hunger and upkeep over time
func _update_hunger(delta: float) -> void:
	# Increment upkeep timer
	upkeep_timer += delta
	
	# Check if upkeep is due
	if upkeep_timer >= upkeep_interval:
		upkeep_timer = 0.0
		_consume_upkeep()
	
	# Hunger still increases over time (slower than before)
	hunger += hunger_rate * delta * 0.5  # 50% slower hunger increase
	
	# Clamp hunger
	hunger = clamp(hunger, 0, max_hunger)
	
	# Check starvation
	if hunger >= max_hunger:
		_die("starvation")

## Consume nutrients from global pool for upkeep
func _consume_upkeep() -> void:
	if not mycelium_manager:
		hunger += 20.0  # Penalty if no manager
		return
	
	# Try to consume from global pool
	if mycelium_manager.current_nutrients >= upkeep_cost:
		# Success - deduct nutrients and reduce hunger
		mycelium_manager.current_nutrients -= upkeep_cost
		mycelium_manager.nutrients_changed.emit(mycelium_manager.current_nutrients, mycelium_manager.max_nutrients)
		hunger = max(0, hunger - 40.0)  # Fed well
		print("Minion consumed %d nutrients (hunger: %.1f)" % [upkeep_cost, hunger])
	else:
		# Failed - increase hunger (starvation)
		hunger += 30.0
		print("Minion starving! Not enough nutrients in pool (hunger: %.1f)" % hunger)


## Update FSM
func _update_state(delta: float) -> void:
	match current_state:
		State.IDLE:
			_state_idle(delta)
		State.SEEKING_NUTRIENT:
			_state_seeking_nutrient(delta)
		State.MOVING_TO_TARGET:
			_state_moving_to_target(delta)
		State.HARVESTING:
			_state_harvesting(delta)


## IDLE: Actively seek nutrients (not passive anymore)
func _state_idle(_delta: float) -> void:
	# Always try to find work (nutrients to harvest)
	# Small delay before seeking again to prevent constant state switching
	if randf() < 0.02:  # ~2% chance per frame = ~1 check per second at 60fps
		_change_state(State.SEEKING_NUTRIENT)


## SEEKING_NUTRIENT: Look for nearby nutrient veins
func _state_seeking_nutrient(_delta: float) -> void:
	# Only search once when entering this state, not every frame
	if target_nutrient_tile != Vector2i(-999, -999):
		# Already have a target, switch to moving
		_change_state(State.MOVING_TO_TARGET)
		return

	# Find nearest nutrient vein (that's adjacent to mycelium)
	var nearest_nutrient = _find_nearest_nutrient()

	if nearest_nutrient != Vector2i(-999, -999):
		print("Minion found nutrient at: %v" % nearest_nutrient)
		# Found nutrient, move to adjacent mycelium tile
		target_nutrient_tile = nearest_nutrient

		# Find a mycelium tile adjacent to the nutrient to stand on
		var harvest_position = _find_mycelium_adjacent_to(target_nutrient_tile)

		if harvest_position != Vector2i(-999, -999):
			var tile_layer = cave_world.get_node("TileMapLayer")
			target_position = tile_layer.map_to_local(harvest_position)

			# Calculate A* path to target
			path = _calculate_path(position, target_position)
			path_index = 0

			if path.is_empty():
				print("No path found to nutrient at %v" % nearest_nutrient)
				_change_state(State.IDLE)
			else:
				print("Path found with %d waypoints to harvest nutrient" % path.size())
				_change_state(State.MOVING_TO_TARGET)
		else:
			# No mycelium adjacent (shouldn't happen due to _find_nearest_nutrient check)
			print("ERROR: Found nutrient but no adjacent mycelium!")
			_change_state(State.IDLE)
	else:
		# No nutrient found, stay idle
		# print("No reachable nutrients found (need mycelium connection)")
		_change_state(State.IDLE)


## MOVING_TO_TARGET: Navigate to target position
func _state_moving_to_target(delta: float) -> void:
	# Move toward target using pathfinding
	_move_along_path(delta)

	# Check if reached end of path
	if path_index >= path.size() and position.distance_to(target_position) < 16.0:
		# Arrived at destination
		_change_state(State.HARVESTING)
		return

	# If path is empty or we're stuck, give up
	if path.is_empty():
		print("Minion has no path - returning to idle")
		_change_state(State.IDLE)
		return


## HARVESTING: Gather nutrients from tile
func _state_harvesting(delta: float) -> void:
	# Stop moving
	velocity = Vector2.ZERO

	# Increment harvest timer
	harvest_timer += delta

	if harvest_timer >= harvest_duration:
		# Harvest complete
		_complete_harvest()


## Find nearest nutrient vein within sight range (that's adjacent to mycelium)
func _find_nearest_nutrient() -> Vector2i:
	if not cave_world or not mycelium_manager:
		return Vector2i(-999, -999)

	var tile_layer = cave_world.get_node("TileMapLayer")
	if not tile_layer:
		return Vector2i(-999, -999)

	var my_tile_pos = tile_layer.local_to_map(position)
	var search_radius = int(sight_range / 16.0)  # Assuming 16px tiles

	var nearest_tile = Vector2i(-999, -999)
	var nearest_distance = INF

	# Search in a square around minion
	for dy in range(-search_radius, search_radius + 1):
		for dx in range(-search_radius, search_radius + 1):
			var check_pos = my_tile_pos + Vector2i(dx, dy)
			var world_pos = tile_layer.map_to_local(check_pos)

			# Check if this is a nutrient tile
			if cave_world.get_tile_at_position(world_pos) == 2:  # TileType.NUTRIENT
				# IMPORTANT: Check if there's mycelium adjacent to this nutrient
				# (so minion can stand on mycelium and harvest the nutrient)
				if _has_mycelium_adjacent_to(check_pos):
					var distance = position.distance_to(world_pos)

					if distance < nearest_distance:
						nearest_distance = distance
						nearest_tile = check_pos

	return nearest_tile


## Check if a tile position has mycelium adjacent to it
func _has_mycelium_adjacent_to(tile_pos: Vector2i) -> bool:
	if not cave_world or not mycelium_manager:
		return false

	var tile_layer = cave_world.get_node("TileMapLayer")
	if not tile_layer:
		return false

	# Check all 4 adjacent positions
	var adjacent_positions = [
		tile_pos + Vector2i(0, -1),  # UP
		tile_pos + Vector2i(1, 0),   # RIGHT
		tile_pos + Vector2i(0, 1),   # DOWN
		tile_pos + Vector2i(-1, 0)   # LEFT
	]

	for adj_pos in adjacent_positions:
		var world_pos = tile_layer.map_to_local(adj_pos)
		if mycelium_manager.has_mycelium_at(world_pos):
			return true

	return false


## Find a mycelium tile adjacent to the given tile (for standing on while harvesting)
func _find_mycelium_adjacent_to(tile_pos: Vector2i) -> Vector2i:
	if not cave_world or not mycelium_manager:
		return Vector2i(-999, -999)

	var tile_layer = cave_world.get_node("TileMapLayer")
	if not tile_layer:
		return Vector2i(-999, -999)

	# Check all 4 adjacent positions, prioritize closest to current position
	var adjacent_positions = [
		tile_pos + Vector2i(0, -1),  # UP
		tile_pos + Vector2i(1, 0),   # RIGHT
		tile_pos + Vector2i(0, 1),   # DOWN
		tile_pos + Vector2i(-1, 0)   # LEFT
	]

	var my_tile_pos = tile_layer.local_to_map(position)
	var best_pos = Vector2i(-999, -999)
	var best_distance = INF

	for adj_pos in adjacent_positions:
		var world_pos = tile_layer.map_to_local(adj_pos)
		if mycelium_manager.has_mycelium_at(world_pos):
			# Found mycelium - check if it's closest to us
			var distance = my_tile_pos.distance_to(adj_pos)
			if distance < best_distance:
				best_distance = distance
				best_pos = adj_pos

	return best_pos


## Calculate path from start to end using A* on mycelium network
func _calculate_path(start: Vector2, end: Vector2) -> Array[Vector2]:
	if not cave_world or not mycelium_manager:
		return []

	var tile_layer = cave_world.get_node("TileMapLayer")
	if not tile_layer:
		return []

	var start_tile = tile_layer.local_to_map(start)
	var end_tile = tile_layer.local_to_map(end)

	# A* pathfinding on mycelium network
	var open_set: Array[Vector2i] = [start_tile]
	var came_from: Dictionary = {}
	var g_score: Dictionary = {start_tile: 0.0}
	var f_score: Dictionary = {start_tile: _heuristic(start_tile, end_tile)}

	while not open_set.is_empty():
		# Find node in open_set with lowest f_score
		var current = _get_lowest_f_score(open_set, f_score)

		# Reached goal
		if current == end_tile:
			return _reconstruct_path(came_from, current, tile_layer)

		open_set.erase(current)

		# Check all neighbors
		var neighbors = _get_walkable_neighbors(current, tile_layer)
		for neighbor in neighbors:
			var tentative_g_score = g_score[current] + 1.0  # Cost is 1 per tile

			if not g_score.has(neighbor) or tentative_g_score < g_score[neighbor]:
				# This path is better
				came_from[neighbor] = current
				g_score[neighbor] = tentative_g_score
				f_score[neighbor] = tentative_g_score + _heuristic(neighbor, end_tile)

				if not open_set.has(neighbor):
					open_set.append(neighbor)

	# No path found
	return []


## Manhattan distance heuristic for A*
func _heuristic(a: Vector2i, b: Vector2i) -> float:
	return abs(a.x - b.x) + abs(a.y - b.y)


## Get node with lowest f_score from open set
func _get_lowest_f_score(open_set: Array[Vector2i], f_score: Dictionary) -> Vector2i:
	var lowest = open_set[0]
	var lowest_score = f_score.get(lowest, INF)

	for node in open_set:
		var score = f_score.get(node, INF)
		if score < lowest_score:
			lowest_score = score
			lowest = node

	return lowest


## Get walkable neighbors (tiles with mycelium)
func _get_walkable_neighbors(tile_pos: Vector2i, tile_layer: TileMapLayer) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	var directions = [
		Vector2i(0, -1),  # UP
		Vector2i(1, 0),   # RIGHT
		Vector2i(0, 1),   # DOWN
		Vector2i(-1, 0)   # LEFT
	]

	for dir in directions:
		var neighbor = tile_pos + dir
		var world_pos = tile_layer.map_to_local(neighbor)

		# Only walkable if has mycelium
		if mycelium_manager.has_mycelium_at(world_pos):
			neighbors.append(neighbor)

	return neighbors


## Reconstruct path from A* came_from chain
func _reconstruct_path(came_from: Dictionary, current: Vector2i, tile_layer: TileMapLayer) -> Array[Vector2]:
	var path: Array[Vector2] = []
	var current_tile = current

	while came_from.has(current_tile):
		path.insert(0, tile_layer.map_to_local(current_tile))
		current_tile = came_from[current_tile]

	# Add final position
	if not path.is_empty():
		path.append(tile_layer.map_to_local(current))

	return path


## Move along current path using waypoints
func _move_along_path(_delta: float) -> void:
	if not mycelium_manager or path.is_empty():
		velocity = Vector2.ZERO
		return

	# Get current waypoint
	if path_index >= path.size():
		# Reached end of path
		velocity = Vector2.ZERO
		return

	var current_waypoint = path[path_index]

	# Move toward current waypoint
	var direction = (current_waypoint - position).normalized()
	var distance_to_waypoint = position.distance_to(current_waypoint)

	# If close enough to waypoint, move to next one
	if distance_to_waypoint < 4.0:  # Within 4 pixels
		path_index += 1
		if path_index >= path.size():
			# Reached final destination
			velocity = Vector2.ZERO
		return

	# Move toward waypoint
	velocity = direction * move_speed


## Complete harvesting action
func _complete_harvest() -> void:
	if not cave_world:
		_change_state(State.IDLE)
		return

	# Harvest the nutrient tile (not the position we're standing on, but the nutrient itself)
	var tile_layer = cave_world.get_node("TileMapLayer")
	if not tile_layer:
		_change_state(State.IDLE)
		return

	var nutrient_world_pos = tile_layer.map_to_local(target_nutrient_tile)
	var success = cave_world.harvest_tile_at_position(nutrient_world_pos)

	if success:
		# Reduce hunger significantly
		hunger = max(0, hunger - 50.0)

		# Emit signal
		nutrient_harvested.emit(nutrient_per_harvest)

		print("Minion harvested nutrient! Hunger reduced to: ", hunger)

	# Reset harvest timer
	harvest_timer = 0.0

	# Return to idle
	target_nutrient_tile = Vector2i(-999, -999)
	_change_state(State.IDLE)


## Change state
func _change_state(new_state: State) -> void:
	if current_state == new_state:
		return

	# Exit current state
	match current_state:
		State.HARVESTING:
			harvest_timer = 0.0
			# Reset rotation from harvesting wobble
			if sprite:
				sprite.rotation = 0.0

	# Enter new state
	current_state = new_state
	# print("Minion state changed to: %s (Hunger: %.1f)" % [_state_to_string(new_state), hunger])
	state_changed.emit(_state_to_string(new_state))

	# State entry logic
	match new_state:
		State.IDLE:
			path.clear()
			path_index = 0
			velocity = Vector2.ZERO
			target_nutrient_tile = Vector2i(-999, -999)
		State.SEEKING_NUTRIENT:
			path.clear()
			path_index = 0
			target_nutrient_tile = Vector2i(-999, -999)  # Clear old target when starting new search


## Die
func _die(reason: String) -> void:
	if not is_alive:
		return

	is_alive = false
	print("Minion died: ", reason)

	minion_died.emit()

	# Visual death effect
	modulate = Color(0.5, 0.5, 0.5, 0.5)

	# Queue free after delay
	await get_tree().create_timer(1.0).timeout
	queue_free()


## Take damage from enemies
func take_damage(amount: int) -> void:
	if not is_alive:
		return
	
	current_health -= amount
	print("Minion took %d damage (HP: %d/%d)" % [amount, current_health, max_health])
	
	if health_bar and health_bar.has_method("update_health"):
		health_bar.update_health(current_health, max_health)
	
	# Visual feedback
	if sprite:
		sprite.modulate = Color(1.0, 0.5, 0.5)  # Flash red
		await get_tree().create_timer(0.1).timeout
		if is_instance_valid(sprite):
			sprite.modulate = Color(1.0, 1.0, 1.0)
	
	if current_health <= 0:
		_die("killed in combat")


## Die
func _update_visuals(delta: float) -> void:
	if not sprite:
		return

	# Flip sprite based on movement direction
	if velocity.x != 0:
		sprite.flip_h = velocity.x < 0

	# Color based on hunger
	var hunger_percent = hunger / max_hunger
	if hunger_percent > 0.8:
		sprite.modulate = Color(1.0, 0.4, 0.4)  # Red when starving
	elif hunger_percent > 0.5:
		sprite.modulate = Color(1.0, 1.0, 0.6)  # Yellow when hungry
	else:
		sprite.modulate = Color(1.0, 1.0, 1.0)  # White when fed

	# Animate based on state
	match current_state:
		State.IDLE:
			_animate_idle_bounce(delta)
		State.MOVING_TO_TARGET:
			_animate_movement(delta)
		State.HARVESTING:
			_animate_harvesting(delta)
		State.SEEKING_NUTRIENT:
			_animate_idle_bounce(delta)  # Similar to idle

	# Subtle hunger-based scale reduction
	var hunger_scale = 1.0 - (hunger_percent * 0.15)  # Shrink up to 15% when starving
	base_scale = Vector2(hunger_scale, hunger_scale)


## Idle bounce animation - gentle up and down bobbing
func _animate_idle_bounce(delta: float) -> void:
	idle_bounce_time += delta * 2.0  # Speed of bounce

	# Sine wave for smooth bounce
	var bounce_offset = sin(idle_bounce_time) * 0.08  # Bounce magnitude
	var squash = 1.0 + bounce_offset * 0.3  # Slight squash when bouncing
	var stretch = 1.0 - bounce_offset * 0.3

	sprite.scale = base_scale * Vector2(squash, stretch)
	sprite.position.y = bounce_offset * 3.0  # Vertical offset


## Movement animation - squash and stretch
func _animate_movement(delta: float) -> void:
	move_animation_time += delta * 8.0  # Speed of squash-stretch cycle

	# Fast squash-stretch for running effect
	var cycle = sin(move_animation_time)
	var horizontal_scale = 1.0 + cycle * 0.2  # Stretch horizontally
	var vertical_scale = 1.0 - cycle * 0.2    # Squash vertically

	sprite.scale = base_scale * Vector2(horizontal_scale, vertical_scale)

	# Small vertical bobbing while moving
	sprite.position.y = abs(cycle) * 2.0


## Harvesting animation - wobble and shake
func _animate_harvesting(_delta: float) -> void:
	# Rapid wobble effect
	var wobble_time = harvest_timer * 10.0
	var wobble = sin(wobble_time) * 0.15

	sprite.scale = base_scale * Vector2(1.0 + wobble, 1.0 - wobble)
	sprite.rotation = wobble * 0.2  # Slight rotation wobble

	# Reset rotation when not harvesting
	if harvest_timer <= 0:
		sprite.rotation = 0


## Spawn animation - pop in effect
func _play_spawn_animation() -> void:
	if not sprite:
		return

	# Start tiny and invisible
	sprite.scale = Vector2.ZERO
	sprite.modulate.a = 0.0

	# Create tween for smooth pop-in
	current_tween = create_tween()
	current_tween.set_parallel(true)  # Run scale and fade together

	# Pop to full size with overshoot
	current_tween.tween_property(sprite, "scale", Vector2.ONE * 1.2, 0.2)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)

	# Then settle back to normal size
	current_tween.chain().tween_property(sprite, "scale", Vector2.ONE, 0.1)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)

	# Fade in
	current_tween.tween_property(sprite, "modulate:a", 1.0, 0.2)


## Helper: Convert state enum to string
func _state_to_string(state: State) -> String:
	match state:
		State.IDLE: return "Idle"
		State.SEEKING_NUTRIENT: return "Seeking Nutrient"
		State.MOVING_TO_TARGET: return "Moving"
		State.HARVESTING: return "Harvesting"
		_: return "Unknown"
