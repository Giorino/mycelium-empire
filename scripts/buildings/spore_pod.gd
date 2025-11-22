class_name SporePod
extends BaseBuilding

## Spore Pod - Housing structure that generates nutrients when a minion works in it
## Each pod has one worker slot

signal worker_assigned(minion: Minion)
signal worker_removed(minion: Minion)

@export_group("Worker System")
@export var max_workers: int = 1
@export var generation_interval: float = 1.0  # Generate every second
@export var nutrients_per_generation: int = 2

# Worker state
var worker_slot: Minion = null
var generation_timer: float = 0.0

# References
var mycelium_manager: Node = null
var worker_bubble: Node2D = null


func _ready() -> void:
	max_health = 100
	super._ready()
	
	# Find mycelium manager
	var cave_world = get_tree().get_first_node_in_group("cave_world")
	if cave_world and cave_world.has_node("MyceliumManager"):
		mycelium_manager = cave_world.get_node("MyceliumManager")
	else:
		push_error("SporePod: MyceliumManager not found!")
	
	# Find worker bubble (should be child node)
	worker_bubble = get_node_or_null("WorkerBubble")
	
	# Initialize bubble visibility
	_update_bubble_visibility()


func _process(delta: float) -> void:
	if has_worker():
		_generate_nutrients(delta)


## Check if the pod can accept a worker
func can_accept_worker() -> bool:
	return worker_slot == null


## Check if the pod has a worker
func has_worker() -> bool:
	# Validate worker is still alive and valid
	if worker_slot != null:
		if not is_instance_valid(worker_slot) or not worker_slot.is_alive:
			# Worker died or was destroyed, clean up
			_clear_worker_slot()
			return false
	
	return worker_slot != null


## Assign a minion to work in this pod
func assign_worker(minion: Minion) -> bool:
	if not can_accept_worker():
		return false
	
	if not is_instance_valid(minion):
		return false
	
	worker_slot = minion
	worker_assigned.emit(minion)
	
	_update_bubble_visibility()
	
	print("SporePod: Worker assigned - %s" % minion.get_instance_id())
	
	return true


## Remove the current worker
func remove_worker() -> void:
	if worker_slot == null:
		return
	
	var minion = worker_slot
	_clear_worker_slot()
	
	worker_removed.emit(minion)
	
	print("SporePod: Worker removed")


## Internal: Clear worker slot and update visuals
func _clear_worker_slot() -> void:
	worker_slot = null
	_update_bubble_visibility()


## Generate nutrients over time (only when worker is present)
func _generate_nutrients(delta: float) -> void:
	generation_timer += delta
	
	if generation_timer >= generation_interval:
		generation_timer = 0.0
		
		# Generate nutrients
		if mycelium_manager and mycelium_manager.has_method("add_nutrients"):
			mycelium_manager.add_nutrients(nutrients_per_generation)
			print("SporePod: Generated %d nutrients (Worker: %s)" % [nutrients_per_generation, worker_slot.get_instance_id()])
		
		# Spawn floating text indicator
		_spawn_nutrient_indicator()


## Spawn floating "+1" text indicator
func _spawn_nutrient_indicator() -> void:
	# Spawn slightly above the pod with small random offset
	var spawn_pos = position + Vector2(randf_range(-8, 8), -16)
	var text = "+%d" % nutrients_per_generation
	
	# Get parent world to spawn in
	var cave_world = get_tree().get_first_node_in_group("cave_world")
	if cave_world:
		FloatingText.spawn(cave_world, spawn_pos, text, Color.CYAN)


## Update worker bubble visibility
func _update_bubble_visibility() -> void:
	if worker_bubble:
		if has_worker():
			_show_worker_bubble()
		else:
			_hide_worker_bubble()


## Show worker bubble with minion inside
func _show_worker_bubble() -> void:
	if not worker_bubble:
		return
	
	worker_bubble.visible = true
	
	# Animate pop-in
	var tween = create_tween()
	tween.tween_property(worker_bubble, "scale", Vector2.ONE * 1.2, 0.15)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)
	tween.tween_property(worker_bubble, "scale", Vector2.ONE, 0.1)\
		.set_trans(Tween.TRANS_SINE)


## Hide worker bubble
func _hide_worker_bubble() -> void:
	if not worker_bubble:
		return
	
	# Animate pop-out
	var tween = create_tween()
	tween.tween_property(worker_bubble, "scale", Vector2.ZERO, 0.15)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_IN)
	
	await tween.finished
	
	if is_instance_valid(worker_bubble):
		worker_bubble.visible = false


## Override die to release worker
func _die() -> void:
	if has_worker():
		# Tell the minion to stop working
		if worker_slot.has_method("stop_working"):
			worker_slot.stop_working()
		remove_worker()
	
	super._die()

