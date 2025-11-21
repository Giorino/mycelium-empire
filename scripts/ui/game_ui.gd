extends Control

## Manages in-game UI display and updates

@onready var nutrient_label: Label = $ResourceDisplay/NutrientLabel
@onready var xp_bar: ProgressBar = $XPBar
@onready var mycelium_manager: Node = get_node("/root/Main/CaveWorld/MyceliumManager")

# Dynamic UI Elements
var action_panel: Panel
var spawn_button: Button
var selected_egg: Node = null # Reference to selected Mother Egg
var build_menu: BuildMenu

const BUILD_MENU_SCENE = preload("res://scenes/ui/build_menu.tscn")

signal building_selected_from_menu(building_data: BuildingData)

func _ready() -> void:
	# Instantiate Build Menu
	build_menu = BUILD_MENU_SCENE.instantiate()
	add_child(build_menu)
	build_menu.building_selected.connect(func(data): emit_signal("building_selected_from_menu", data))
	
	if mycelium_manager:
		mycelium_manager.nutrients_changed.connect(_on_nutrients_changed)
		# Initialize display
		_on_nutrients_changed(mycelium_manager.current_nutrients, mycelium_manager.starting_nutrients)
	else:
		push_error("GameUI: Could not find MyceliumManager!")
	
	# Connect to ExperienceManager
	ExperienceManager.xp_gained.connect(_on_xp_gained)
	_on_xp_gained(ExperienceManager.current_xp, ExperienceManager.target_xp)
	
	_setup_action_panel()

func _setup_action_panel() -> void:
	# Create a simple action panel for unit commands
	action_panel = Panel.new()
	action_panel.visible = false
	action_panel.custom_minimum_size = Vector2(200, 100)
	# Position bottom center
	action_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	# Reset position to let anchors work, then offset up
	action_panel.position = Vector2.ZERO 
	action_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	action_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	action_panel.add_child(vbox)
	
	# Label
	var label = Label.new()
	label.text = "Mother Egg Actions"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label)
	
	# Spawn Button
	spawn_button = Button.new()
	spawn_button.text = "Incubate Spore (50 Nutrients)"
	spawn_button.pressed.connect(_on_spawn_button_pressed)
	vbox.add_child(spawn_button)
	
	# Add margin from bottom
	var margin_container = MarginContainer.new()
	margin_container.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	margin_container.add_theme_constant_override("margin_bottom", 20)
	margin_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	margin_container.grow_vertical = Control.GROW_DIRECTION_BEGIN
	margin_container.add_child(action_panel)
	
	add_child(margin_container)

func _on_nutrients_changed(current: int, _max: int) -> void:
	if nutrient_label:
		nutrient_label.text = "Nutrients: %d" % current
	
	# Update button availability
	if spawn_button:
		# Use a safe default cost if no egg is selected, otherwise query the egg
		var cost = 50
		if selected_egg and "minion_cost" in selected_egg:
			cost = selected_egg.minion_cost
		spawn_button.disabled = current < cost

	if build_menu:
		build_menu.update_affordability(current)

func _on_xp_gained(current: float, target: float) -> void:
	if xp_bar:
		xp_bar.max_value = target
		xp_bar.value = current

## Show actions for the mother egg
func show_egg_actions(egg: Node) -> void:
	selected_egg = egg
	action_panel.visible = true
	
	# Update button text with cost
	if spawn_button and "minion_cost" in egg:
		spawn_button.text = "Incubate Spore (%d Nutrients)" % egg.minion_cost
		# Re-check affordability immediately
		if mycelium_manager:
			spawn_button.disabled = mycelium_manager.current_nutrients < egg.minion_cost
	
## Hide actions
func clear_selection() -> void:
	selected_egg = null
	action_panel.visible = false

func _on_spawn_button_pressed() -> void:
	print("GameUI: Spawn button pressed")
	if selected_egg:
		print("GameUI: Selected egg is valid")
		if selected_egg.has_method("spawn_minion"):
			print("GameUI: Calling spawn_minion()")
			var success = selected_egg.spawn_minion()
			if success:
				print("GameUI: Spawn success")
				# Optional: floating text or sound
				pass
			else:
				print("GameUI: Spawn failed (returned false)")
		else:
			print("GameUI: Selected egg missing spawn_minion method!")
	else:
		print("GameUI: No selected egg!")

func toggle_build_menu() -> void:
	if build_menu:
		build_menu.toggle()
