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
		var card = _create_upgrade_card(upgrade)
		card_container.add_child(card)

func _create_upgrade_card(upgrade: Resource) -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(250, 350)
	
	# Layout
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 15)
	
	# Add margin
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	btn.add_child(margin)
	margin.add_child(vbox)
	
	# Title
	var title_lbl = Label.new()
	title_lbl.text = upgrade.name
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_lbl.add_theme_font_size_override("font_size", 32)
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title_lbl)
	
	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size.y = 20
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(spacer)
	
	# Description
	var desc_lbl = Label.new()
	desc_lbl.text = upgrade.description
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 28)
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(desc_lbl)
	
	# Connect signal
	btn.pressed.connect(_on_upgrade_selected.bind(upgrade))
	
	return btn

func _on_upgrade_selected(upgrade: Resource) -> void:
	ExperienceManager.apply_upgrade(upgrade)
	get_tree().paused = false
	visible = false
