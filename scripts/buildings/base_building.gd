class_name BaseBuilding
extends Node2D

## Base class for all buildings

@export var max_health: int = 100
var current_health: int

@onready var health_bar: Node2D = $HealthBar if has_node("HealthBar") else null
@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null

func _ready() -> void:
	current_health = max_health
	if health_bar and health_bar.has_method("setup"):
		health_bar.setup(current_health, max_health)

func take_damage(amount: int) -> void:
	current_health -= amount
	print("%s took %d damage (HP: %d/%d)" % [name, amount, current_health, max_health])
	
	if health_bar and health_bar.has_method("update_health"):
		health_bar.update_health(current_health, max_health)
	
	# Visual feedback
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color(1, 0, 0), 0.1)
		tween.tween_property(sprite, "modulate", Color(1, 1, 1), 0.1)
		
	if current_health <= 0:
		_die()

func _die() -> void:
	queue_free()
