class_name FloatingText
extends Node2D

## Floating damage-number style text indicator (like in Brotato)
## Automatically animates upward and fades out, then self-destructs

@export var text: String = "+1"
@export var color: Color = Color.GREEN
@export var duration: float = 1.0
@export var float_distance: float = 30.0
@export var font_size: int = 24

var label: Label

func _ready() -> void:
	# Create label
	label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	
	# Add outline for readability
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	
	# Center the label
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.pivot_offset = label.size / 2
	
	add_child(label)
	
	# Start animation
	_animate()


func _animate() -> void:
	label.scale = Vector2.ZERO
	
	# Create scale tween (pop in then settle)
	var scale_tween = create_tween()
	scale_tween.tween_property(label, "scale", Vector2.ONE * 1.3, 0.15)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)
	scale_tween.tween_property(label, "scale", Vector2.ONE, 0.1)\
		.set_trans(Tween.TRANS_SINE)
	
	# Create position tween (float upward) - runs in parallel
	var pos_tween = create_tween()
	pos_tween.tween_property(self, "position:y", position.y - float_distance, duration)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)
	
	# Fade out (start fading halfway through)
	await get_tree().create_timer(duration * 0.5).timeout
	if is_instance_valid(label):
		var fade_tween = create_tween()
		fade_tween.tween_property(label, "modulate:a", 0.0, duration * 0.5)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_IN)
	
	# Self-destruct after animation
	await get_tree().create_timer(duration * 0.5).timeout
	queue_free()


## Static helper to spawn floating text at a position
static func spawn(parent: Node, world_pos: Vector2, text_str: String, text_color: Color = Color.GREEN) -> FloatingText:
	var floating_text = FloatingText.new()
	floating_text.text = text_str
	floating_text.color = text_color
	floating_text.position = world_pos
	
	parent.add_child(floating_text)
	
	return floating_text
