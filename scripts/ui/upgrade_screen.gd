extends CanvasLayer

@onready var card_container: HBoxContainer = $VBoxContainer/CardContainer

var available_upgrades: Array[Resource] = [
	preload("res://resources/upgrades/speedy_spores.tres"),
	preload("res://resources/upgrades/hardened_shells.tres"),
	preload("res://resources/upgrades/sharp_mandibles.tres")
]

func _ready() -> void:
	visible = false
	ExperienceManager.level_up.connect(_on_level_up)

func _on_level_up(_new_level: int) -> void:
	get_tree().paused = true
	visible = true
	_generate_cards()

func _generate_cards() -> void:
	# Clear existing cards
	for child in card_container.get_children():
		child.queue_free()
	
	# Pick 3 random upgrades (or all if < 3)
	var options = available_upgrades.duplicate()
	options.shuffle()
	var choices = options.slice(0, 3)
	
	for upgrade in choices:
		var btn = Button.new()
		btn.text = "%s\n\n%s" % [upgrade.name, upgrade.description]
		btn.custom_minimum_size = Vector2(150, 200)
		# Connect with a bind to pass the specific upgrade data
		btn.pressed.connect(_on_upgrade_selected.bind(upgrade))
		card_container.add_child(btn)

func _on_upgrade_selected(upgrade: Resource) -> void:
	ExperienceManager.apply_upgrade(upgrade)
	get_tree().paused = false
	visible = false
