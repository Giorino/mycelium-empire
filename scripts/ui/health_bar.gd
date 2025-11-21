class_name HealthBar
extends Node2D

## Reusable health bar component

@onready var progress_bar: TextureProgressBar = $TextureProgressBar
@onready var timer: Timer = $Timer

@export var hide_when_full: bool = true
@export var fade_time: float = 0.5
@export var visible_duration: float = 2.0

func _ready() -> void:
	if hide_when_full:
		modulate.a = 0.0
	
	if timer:
		timer.wait_time = visible_duration
		timer.timeout.connect(_on_timer_timeout)

func setup(current: int, max_val: int) -> void:
	if progress_bar:
		progress_bar.max_value = max_val
		progress_bar.value = current
	
	if hide_when_full and current >= max_val:
		modulate.a = 0.0
	else:
		modulate.a = 1.0

func update_health(current: int, max_val: int) -> void:
	if progress_bar:
		progress_bar.max_value = max_val
		progress_bar.value = current
	
	# Show bar
	modulate.a = 1.0
	
	# Restart hide timer
	if timer:
		timer.start()

func _on_timer_timeout() -> void:
	if hide_when_full:
		var tween = create_tween()
		tween.tween_property(self, "modulate:a", 0.0, fade_time)
