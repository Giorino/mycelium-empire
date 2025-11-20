class_name MinionManager
extends Node2D

## Manages minion spawning, lifecycle, and colony statistics

signal minion_spawned(minion: Node)
signal minion_count_changed(count: int)
signal total_nutrients_harvested_changed(total: int)

@export_group("Spawning")
@export var minion_scene: PackedScene
@export var spawn_on_first_mycelium: bool = true
@export var initial_minion_count: int = 1
@export var max_minions: int = 10
@export var minions_per_mycelium_placement: int = 0  # Spawn this many minions per placement (0 = only first time)

@export_group("Spawn Locations")
@export var spawn_radius: float = 25.0

# Colony stats
var active_minions: Array[Node] = []
var total_nutrients_harvested: int = 0
var has_spawned_initial: bool = false

# References
@onready var mycelium_manager: Node = get_parent().get_node("MyceliumManager")


func _ready() -> void:
	# Connect to mycelium placement signal
	if mycelium_manager and mycelium_manager.has_signal("mycelium_placed"):
		mycelium_manager.mycelium_placed.connect(_on_mycelium_placed)


## Find a good spawn position (on or near mycelium)
func _find_spawn_position() -> Vector2:
	# Default center position
	var center = Vector2(800, 480)

	# If mycelium manager exists, try to find mycelium
	if mycelium_manager and mycelium_manager.has_method("get_mycelium_count"):
		var mycelium_count = mycelium_manager.get_mycelium_count()

		if mycelium_count > 0:
			# Try random positions near center to find mycelium
			for attempt in range(20):
				var test_pos = center + Vector2(
					randf_range(-200, 200),
					randf_range(-200, 200)
				)

				if mycelium_manager.has_method("has_mycelium_at") and mycelium_manager.has_mycelium_at(test_pos):
					return test_pos

	# Fallback to random position near center
	return center + Vector2(
		randf_range(-spawn_radius, spawn_radius),
		randf_range(-spawn_radius, spawn_radius)
	)


## Spawn a new minion at position
func spawn_minion(spawn_pos: Vector2) -> Node:
	if active_minions.size() >= max_minions:
		print("Cannot spawn minion: max limit reached (%d)" % max_minions)
		return null

	if not minion_scene:
		push_error("MinionManager: No minion scene assigned!")
		return null

	# Instantiate minion
	var minion = minion_scene.instantiate()
	if not minion:
		push_error("MinionManager: Failed to instantiate minion!")
		return null

	# Set position
	minion.position = spawn_pos

	# Connect signals
	minion.nutrient_harvested.connect(_on_minion_harvested_nutrient)
	minion.minion_died.connect(_on_minion_died.bind(minion))
	minion.state_changed.connect(_on_minion_state_changed.bind(minion))

	# Add to scene
	add_child(minion)

	# Track minion
	active_minions.append(minion)

	# Emit signals
	minion_spawned.emit(minion)
	minion_count_changed.emit(active_minions.size())

	print("Minion spawned at: %v (Total: %d)" % [spawn_pos, active_minions.size()])

	return minion


## Handle minion harvesting nutrient
func _on_minion_harvested_nutrient(amount: int) -> void:
	total_nutrients_harvested += amount

	# Add to mycelium manager resources
	if mycelium_manager and mycelium_manager.has_method("add_nutrients"):
		mycelium_manager.add_nutrients(amount)

	total_nutrients_harvested_changed.emit(total_nutrients_harvested)

	print("Minion harvested %d nutrients (Colony total: %d)" % [amount, total_nutrients_harvested])


## Handle minion death
func _on_minion_died(minion: Node) -> void:
	active_minions.erase(minion)
	minion_count_changed.emit(active_minions.size())

	print("Minion died. Remaining: %d" % active_minions.size())


## Handle minion state change (for debugging/UI)
func _on_minion_state_changed(new_state: String, minion: Node) -> void:
	# Could be used for UI updates or debugging
	pass


## Get current minion count
func get_minion_count() -> int:
	return active_minions.size()


## Get total nutrients harvested by colony
func get_total_nutrients_harvested() -> int:
	return total_nutrients_harvested

## Reset colony
func reset_colony() -> void:
	# Despawn all active minions
	for minion in active_minions:
		if is_instance_valid(minion):
			minion.queue_free()

	active_minions.clear()
	minion_count_changed.emit(active_minions.size())
	total_nutrients_harvested = 0
	has_spawned_initial = false


## Called when mycelium is placed
func _on_mycelium_placed(grid_pos: Vector2i) -> void:
	# Spawn initial minions on first placement
	if spawn_on_first_mycelium and not has_spawned_initial:
		has_spawned_initial = true

		# Convert grid position to world position
		var world_pos = Vector2(grid_pos.x * 16, grid_pos.y * 16)  # Assuming 16px tiles

		# Spawn initial minions at this location
		for i in range(initial_minion_count):
			await get_tree().create_timer(0.3).timeout  # Stagger spawns
			var offset = Vector2(randf_range(-20, 20), randf_range(-20, 20))
			spawn_minion(world_pos + offset)

		print("Initial minions spawned at first mycelium placement!")
	# Optionally spawn more minions on each placement
	elif minions_per_mycelium_placement > 0 and active_minions.size() < max_minions:
		var world_pos = Vector2(grid_pos.x * 16, grid_pos.y * 16)
		for i in range(minions_per_mycelium_placement):
			if active_minions.size() >= max_minions:
				break
			spawn_minion(world_pos + Vector2(randf_range(-10, 10), randf_range(-10, 10)))
