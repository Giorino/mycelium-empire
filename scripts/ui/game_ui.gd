extends Control

## Manages in-game UI display and updates

@onready var nutrient_label: Label = $ResourceDisplay/NutrientLabel
@onready var mycelium_manager: Node = get_node("/root/Main/CaveWorld/MyceliumManager")


func _ready() -> void:
	if mycelium_manager:
		mycelium_manager.nutrients_changed.connect(_on_nutrients_changed)
		# Initialize display
		_on_nutrients_changed(mycelium_manager.current_nutrients, mycelium_manager.starting_nutrients)
	else:
		push_error("GameUI: Could not find MyceliumManager!")


func _on_nutrients_changed(current: int, _max: int) -> void:
	if nutrient_label:
		nutrient_label.text = "Nutrients: %d" % current
