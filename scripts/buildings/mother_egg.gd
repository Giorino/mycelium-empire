class_name MotherEgg
extends BaseBuilding

## The heart of the colony. If destroyed, game over.

func _ready() -> void:
	max_health = 500 # Stronger than normal buildings
	super._ready()

func _die() -> void:
	print("MOTHER EGG DESTROYED! GAME OVER!")
	# TODO: Trigger actual game over sequence
	# For now, just restart scene or show message
	get_tree().reload_current_scene()
