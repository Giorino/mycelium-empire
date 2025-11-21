class_name BuildMenu
extends Control

signal building_selected(building_data: BuildingData)

@onready var grid_container: GridContainer = $Panel/ScrollContainer/GridContainer
@onready var panel: Panel = $Panel

# Preload building resources
# In a larger project, we might scan a directory, but for now we'll list them
var building_paths = [
	"res://resources/buildings/mother_egg.tres",
	"res://resources/buildings/spore_pod.tres",
	"res://resources/buildings/defense_tower.tres"
]

var buildings: Array[BuildingData] = []
var building_cards: Dictionary = {} # BuildingData -> Control (Card)

func _ready() -> void:
	_load_buildings()
	_create_building_cards()
	
	# Start hidden
	visible = false
	modulate.a = 0.0

func _load_buildings() -> void:
	buildings.clear()
	for path in building_paths:
		var resource = load(path)
		if resource and resource is BuildingData:
			if resource.is_visible_in_menu:
				buildings.append(resource)
	
	# Sort by menu_order
	buildings.sort_custom(func(a, b): return a.menu_order < b.menu_order)

func _create_building_cards() -> void:
	# Clear existing
	for child in grid_container.get_children():
		child.queue_free()
		
	for building in buildings:
		var card = _create_card(building)
		grid_container.add_child(card)
		building_cards[building] = card

const BuildingCardScript = preload("res://scripts/ui/building_card.gd")

func _create_card(building: BuildingData) -> Control:
	var card = BuildingCardScript.new()
	card.custom_minimum_size = Vector2(200, 260)
	card.toggle_mode = false
	
	# Layout
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	# Add some margin
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE # Let button handle clicks
	
	card.add_child(margin)
	margin.add_child(vbox)
	
	# Icon
	var icon_rect = TextureRect.new()
	icon_rect.texture = building.icon
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.custom_minimum_size = Vector2(100, 100)
	icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(icon_rect)
	
	# Name
	var name_lbl = Label.new()
	name_lbl.text = building.name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_lbl.add_theme_font_size_override("font_size", 32)
	vbox.add_child(name_lbl)
	
	# Cost
	var cost_lbl = Label.new()
	if building.nutrient_cost == 0:
		cost_lbl.text = "FREE"
		cost_lbl.add_theme_color_override("font_color", Color.GREEN_YELLOW)
	else:
		cost_lbl.text = "%d Nutrients" % building.nutrient_cost
		cost_lbl.add_theme_color_override("font_color", Color.CYAN)
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_lbl.add_theme_font_size_override("font_size", 24)
	vbox.add_child(cost_lbl)
	
	# Description (Tooltip or small text)
	card.tooltip_text = building.description

	card.pressed.connect(func(): _on_card_pressed(building))
	
	return card

func _on_card_pressed(building: BuildingData) -> void:
	emit_signal("building_selected", building)
	toggle(false) # Close menu on selection

func toggle(force_state: Variant = null) -> void:
	if force_state != null:
		visible = force_state
	else:
		visible = !visible
		
	if visible:
		# Animate in
		var tween = create_tween()
		tween.tween_property(self, "modulate:a", 1.0, 0.2)
	else:
		modulate.a = 0.0

func update_affordability(current_nutrients: int) -> void:
	for building in building_cards:
		var card = building_cards[building]
		var is_affordable = current_nutrients >= building.nutrient_cost
		
		card.disabled = !is_affordable
		if is_affordable:
			card.modulate = Color.WHITE
		else:
			card.modulate = Color(0.5, 0.5, 0.5, 0.8) # Dimmed
