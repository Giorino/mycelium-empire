class_name Predator
extends CharacterBody2D

## Hostile cave predator that hunts minions

signal predator_died

# States for FSM
enum State {
	IDLE,
	PATROL,
	CHASE,
	ATTACK
}

@export_group("Movement")
@export var move_speed: float = 40.0  # Base speed
@export var mycelium_speed_penalty: float = 0.5  # Slowed on mycelium

@export_group("Combat")
@export var detection_range: float = 150.0
@export var attack_range: float = 100.0
@export var attack_damage: int = 100
@export var attack_cooldown: float = 1.5
@export var max_health: int = 50

# State
var current_state: State = State.IDLE
var current_health: int = 50
var is_alive: bool = true

# Targeting
var target_entity: Node2D = null
var attack_timer: float = 0.0

# Patrol
var patrol_direction: Vector2 = Vector2.ZERO
var patrol_change_timer: float = 0.0
var patrol_change_interval: float = 3.0

# References
var mycelium_manager: Node = null
var minion_manager: Node = null
var building_manager: Node = null

# Visuals
@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D if has_node("NavigationAgent2D") else null
@onready var health_bar: Node2D = $HealthBar if has_node("HealthBar") else null


func _ready() -> void:
	current_health = max_health
	if health_bar and health_bar.has_method("setup"):
		health_bar.setup(current_health, max_health)
	
	# Find references
	var cave_world = get_tree().get_first_node_in_group("cave_world")
	if cave_world:
		mycelium_manager = cave_world.get_node_or_null("MyceliumManager")
		minion_manager = cave_world.get_node_or_null("MinionManager")
		building_manager = cave_world.get_node_or_null("BuildingManager")
	
	_change_state(State.PATROL)
	
	# Setup navigation
	if nav_agent:
		nav_agent.velocity_computed.connect(_on_nav_velocity_computed)
		nav_agent.max_speed = move_speed


func _process(delta: float) -> void:
	if not is_alive:
		return
	
	# Update attack cooldown
	if attack_timer > 0:
		attack_timer -= delta
	
	# Update FSM
	_update_state(delta)


func _physics_process(_delta: float) -> void:
	if not is_alive:
		return
	
	# Check if on mycelium for speed penalty
	var _effective_speed = move_speed
	if mycelium_manager and mycelium_manager.has_mycelium_at(global_position):
		_effective_speed *= mycelium_speed_penalty
	
	# Apply velocity with speed
	# velocity = velocity.normalized() * effective_speed
	# move_and_slide()
	
	# If using navigation agent, we don't move here directly unless not navigating
	if not nav_agent or nav_agent.is_navigation_finished():
		move_and_slide()
	else:
		# Navigation agent handles movement in _physics_process via callback or manual velocity set
		pass


## Update FSM
func _update_state(delta: float) -> void:
	match current_state:
		State.IDLE:
			_state_idle(delta)
		State.PATROL:
			_state_patrol(delta)
		State.CHASE:
			_state_chase(delta)
		State.ATTACK:
			_state_attack(delta)


## IDLE: Wait briefly
func _state_idle(_delta: float) -> void:
	velocity = Vector2.ZERO
	# Transition to patrol after a moment
	if randf() < 0.05:
		_change_state(State.PATROL)


## PATROL: Random movement
func _state_patrol(delta: float) -> void:
	# Check for targets
	var target = _find_nearest_target()
	if target:
		target_entity = target
		_change_state(State.CHASE)
		return
	
	# Change direction periodically
	patrol_change_timer += delta
	if patrol_change_timer >= patrol_change_interval:
		patrol_change_timer = 0.0
		patrol_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	
	velocity = patrol_direction * move_speed
	move_and_slide()


## CHASE: Pursue target
func _state_chase(_delta: float) -> void:
	if not is_instance_valid(target_entity):
		target_entity = null
		_change_state(State.PATROL)
		return
	
	# Check if in attack range
	var distance = global_position.distance_to(target_entity.global_position)
	
	print("Chase: Distance to target: %.1f (Attack Range: %.1f)" % [distance, attack_range])
	
	if distance <= attack_range:
		print("Chase: In range! Switching to ATTACK.")
		_change_state(State.ATTACK)
		return
	
	# Check if out of detection range
	if distance > detection_range * 1.5:  # Give some leeway
		print("Chase: Target lost (too far: %.1f). Switching to PATROL." % distance)
		target_entity = null
		_change_state(State.PATROL)
		return
	
	# Move toward target using navigation
	if nav_agent:
		nav_agent.target_position = target_entity.global_position
		var next_path_pos = nav_agent.get_next_path_position()
		var direction = (next_path_pos - global_position).normalized()
		
		# Calculate intended velocity
		var intended_velocity = direction * move_speed
		nav_agent.set_velocity(intended_velocity)
	else:
		# Fallback to direct movement
		var direction = (target_entity.global_position - global_position).normalized()
		velocity = direction * move_speed
		move_and_slide()


## ATTACK: Damage target
func _state_attack(_delta: float) -> void:
	if not is_instance_valid(target_entity):
		target_entity = null
		_change_state(State.PATROL)
		return
	
	# Stop moving
	velocity = Vector2.ZERO
	
	# Check if still in range
	var distance = global_position.distance_to(target_entity.global_position)
	if distance > attack_range * 1.2:
		_change_state(State.CHASE)
		return
	
	# Attack if cooldown ready
	if attack_timer <= 0:
		_perform_attack()
		attack_timer = attack_cooldown


## Find nearest minion or building in detection range
func _find_nearest_target() -> Node2D:
	var nearest: Node2D = null
	var min_dist: float = detection_range
	
	# Check minions
	if minion_manager:
		for minion in minion_manager.active_minions:
			if is_instance_valid(minion):
				var dist = global_position.distance_to(minion.global_position)
				if dist < min_dist:
					min_dist = dist
					nearest = minion
	
	# Check buildings
	if building_manager:
		for building in building_manager.buildings.values():
			if is_instance_valid(building):
				var dist = global_position.distance_to(building.global_position)
				if dist < min_dist:
					min_dist = dist
					nearest = building
					
	return nearest


## Perform attack on target
func _perform_attack() -> void:
	if is_instance_valid(target_entity):
		# Visual feedback
		var original_scale = sprite.scale
		var original_modulate = sprite.modulate
		
		var tween = create_tween()
		tween.tween_property(sprite, "scale", original_scale * 1.2, 0.1)
		tween.tween_property(sprite, "modulate", Color(1, 0, 0), 0.1)
		tween.tween_property(sprite, "scale", original_scale, 0.1)
		tween.tween_property(sprite, "modulate", original_modulate, 0.1)
		
		if target_entity.has_method("take_damage"):
			target_entity.take_damage(attack_damage)
			print("Predator attacked %s for %d damage!" % [target_entity.name, attack_damage])


## Take damage
func take_damage(amount: int) -> void:
	if not is_alive:
		return
	
	current_health -= amount
	print("Predator took %d damage (HP: %d/%d)" % [amount, current_health, max_health])
	
	if health_bar and health_bar.has_method("update_health"):
		health_bar.update_health(current_health, max_health)
	
	if current_health <= 0:
		_die()


## Die
func _die() -> void:
	if not is_alive:
		return
	
	is_alive = false
	print("Predator died!")
	
	predator_died.emit()
	
	# Visual death effect
	if sprite:
		sprite.modulate = Color(0.5, 0.5, 0.5, 0.5)
	
	# Queue free after delay
	await get_tree().create_timer(1.0).timeout
	queue_free()


## Change state
func _change_state(new_state: State) -> void:
	if current_state == new_state:
		return
	
	current_state = new_state
	print("Predator state: %s" % _state_to_string(new_state))
	
	# State entry logic
	match new_state:
		State.PATROL:
			patrol_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()


## Helper: State to string
func _state_to_string(state: State) -> String:
	match state:
		State.IDLE: return "Idle"
		State.PATROL: return "Patrol"
		State.CHASE: return "Chase"
		State.ATTACK: return "Attack"
		_: return "Unknown"


## Navigation callback
func _on_nav_velocity_computed(safe_velocity: Vector2) -> void:
	if not is_alive:
		return
		
	# Apply mycelium penalty
	var effective_speed_mult = 1.0
	if mycelium_manager and mycelium_manager.has_mycelium_at(global_position):
		effective_speed_mult = mycelium_speed_penalty
		
	velocity = safe_velocity * effective_speed_mult
	move_and_slide()
