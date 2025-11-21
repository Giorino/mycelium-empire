class_name BuildingCard
extends Button

func _make_custom_tooltip(for_text: String) -> Control:
	var container = PanelContainer.new()
	
	# Optional: Style the panel if needed, or use default
	# var style = StyleBoxFlat.new()
	# style.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	# container.add_theme_stylebox_override("panel", style)
	
	var label = Label.new()
	label.text = for_text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 300 # Max width
	
	# Increase font size
	label.add_theme_font_size_override("font_size", 24)
	
	# Add some padding via margin container inside panel if needed, 
	# but PanelContainer usually handles it. 
	# Let's just add the label directly for now.
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_child(label)
	
	container.add_child(margin)
	
	return container
