class_name EnemyManager
extends Node2D

## Manages enemy spawning and tracking

signal enemy_spawned(enemy: Node)
signal enemy_died(enemy: Node)

@export_group("Spawning")
@export var predator_scene: PackedScene
@export var spawn_interval: float = 30.0  # Seconds between spawns
@export var spawn_radius_min: float = 300.0  # Min distance from center
@export var spawn_radius_max: float = 500.0  # Max distance from center
@export var max_enemies: int = 5
@export var initial_spawn_delay: float = 60.0  # Wait before first spawn

# State
var active_enemies: Array[Node] = []
var spawn_timer: float = 0.0
var has_started: bool = false


func _ready() -> void:
	# Wait before starting spawns
	spawn_timer = -initial_spawn_delay


func _process(delta: float) -> void:
	_update_spawning(delta)


## Update spawn timer
func _update_spawning(delta: float) -> void:
	if not has_started:
		spawn_timer += delta
		if spawn_timer >= 0:
			has_started = true
			spawn_timer = 0.0
			print("EnemyManager: Spawning starting!")
		return
	
	spawn_timer += delta
	
	if spawn_timer >= spawn_interval and active_enemies.size() < max_enemies:
		spawn_timer = 0.0
		_spawn_predator()


## Spawn a predator at random position
func _spawn_predator() -> void:
	if not predator_scene:
		push_error("EnemyManager: No predator scene assigned!")
		return
	
	# Find spawn position (outside camera view)
	var spawn_pos = _get_spawn_position()
	
	# Instantiate predator
	var predator = predator_scene.instantiate()
	if not predator:
		push_error("EnemyManager: Failed to instantiate predator!")
		return
	
	predator.position = spawn_pos
	
	# Connect signals
	if predator.has_signal("predator_died"):
		predator.predator_died.connect(_on_predator_died.bind(predator))
	
	# Add to scene
	add_child(predator)
	
	# Track enemy
	active_enemies.append(predator)
	
	enemy_spawned.emit(predator)
	print("Predator spawned at %v (Total: %d)" % [spawn_pos, active_enemies.size()])


## Get random spawn position outside center
func _get_spawn_position() -> Vector2:
	# Get camera center (or world center)
	var center = Vector2(800, 480)  # Default center
	
	var camera = get_viewport().get_camera_2d()
	if camera:
		center = camera.get_screen_center_position()
	
	# Random angle
	var angle = randf() * TAU
	var distance = randf_range(spawn_radius_min, spawn_radius_max)
	
	var offset = Vector2(cos(angle), sin(angle)) * distance
	var potential_pos = center + offset
	
	# Check if position is valid (not in wall and inside bounds)
	var cave_world = get_tree().get_first_node_in_group("cave_world")
	if cave_world:
		var bounds = Rect2()
		if cave_world.has_method("get_cave_bounds"):
			bounds = cave_world.get_cave_bounds()
		
		# Try up to 10 times to find a valid position
		for i in range(10):
			var is_in_bounds = bounds.has_point(potential_pos)
			var tile_type = -1
			
			if cave_world.has_method("get_tile_at_position"):
				tile_type = cave_world.get_tile_at_position(potential_pos)
			
			# Valid if inside bounds AND is EMPTY (0)
			if is_in_bounds and tile_type == 0: # 0 is EMPTY
				return potential_pos
			
			# Try another random position
			angle = randf() * TAU
			distance = randf_range(spawn_radius_min, spawn_radius_max)
			offset = Vector2(cos(angle), sin(angle)) * distance
			potential_pos = center + offset
			
	return potential_pos


## Handle predator death
func _on_predator_died(predator: Node) -> void:
	active_enemies.erase(predator)
	enemy_died.emit(predator)
	print("Predator died. Remaining: %d" % active_enemies.size())


## Get current enemy count
func get_enemy_count() -> int:
	return active_enemies.size()
