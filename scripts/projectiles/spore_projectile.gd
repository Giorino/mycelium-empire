class_name SporeProjectile
extends Area2D

## Projectile fired by Spore Tower

@export var speed: float = 300.0
@export var damage: int = 20
@export var lifetime: float = 2.0

var target: Node2D = null
var velocity: Vector2 = Vector2.ZERO

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	
	# Auto-destroy after lifetime
	await get_tree().create_timer(lifetime).timeout
	queue_free()


func _process(delta: float) -> void:
	if is_instance_valid(target):
		# Homing behavior
		var direction = (target.global_position - global_position).normalized()
		velocity = velocity.lerp(direction * speed, 5.0 * delta)
	else:
		# Continue straight if target lost
		pass
		
	position += velocity * delta


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		queue_free()
