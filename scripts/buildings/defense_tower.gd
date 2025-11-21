class_name DefenseTower
extends Node2D

## Defensive structure that shoots at enemies

@export var range_radius: float = 200.0
@export var fire_rate: float = 1.0
@export var projectile_scene: PackedScene

var fire_timer: float = 0.0
var current_target: Node2D = null

@onready var detection_area: Area2D = $DetectionArea
@onready var collision_shape: CollisionShape2D = $DetectionArea/CollisionShape2D
@onready var health_bar: Node2D = $HealthBar if has_node("HealthBar") else null

@export var max_health: int = 200
var current_health: int = 200

func _ready() -> void:
	if collision_shape:
		collision_shape.shape.radius = range_radius
	
	current_health = max_health
	if health_bar and health_bar.has_method("setup"):
		health_bar.setup(current_health, max_health)


func _process(delta: float) -> void:
	fire_timer -= delta
	
	if fire_timer <= 0:
		_try_fire()


func _try_fire() -> void:
	# Find target if none or invalid
	if not is_instance_valid(current_target):
		current_target = _find_nearest_enemy()
	
	# If still no target, return
	if not current_target:
		return
		
	# Check if target is still in range
	if global_position.distance_to(current_target.global_position) > range_radius:
		current_target = null
		return
		
	# Fire!
	_fire_projectile(current_target)
	fire_timer = fire_rate


func _find_nearest_enemy() -> Node2D:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var nearest_dist = range_radius
	
	for enemy in enemies:
		var dist = global_position.distance_to(enemy.global_position)
		if dist < nearest_dist:
			nearest = enemy
			nearest_dist = dist
			
	return nearest


func _fire_projectile(target: Node2D) -> void:
	if not projectile_scene:
		return
		
	var projectile = projectile_scene.instantiate()
	projectile.global_position = global_position
	projectile.target = target
	projectile.velocity = (target.global_position - global_position).normalized() * projectile.speed
	
	get_tree().root.add_child(projectile)


## Take damage
func take_damage(amount: int) -> void:
	current_health -= amount
	print("Defense Tower took %d damage (HP: %d/%d)" % [amount, current_health, max_health])
	
	if health_bar and health_bar.has_method("update_health"):
		health_bar.update_health(current_health, max_health)
		
	if current_health <= 0:
		_die()


func _die() -> void:
	queue_free()
