extends Node

signal xp_gained(current_xp: float, target_xp: float)
signal level_up(new_level: int)

var current_xp: float = 0.0
var target_xp: float = 10.0
var current_level: int = 1

const TARGET_XP_GROWTH: float = 1.5

func add_xp(amount: float) -> void:
	current_xp += amount
	emit_signal("xp_gained", current_xp, target_xp)
	
	if current_xp >= target_xp:
		_handle_level_up()

func _handle_level_up() -> void:
	current_xp -= target_xp
	current_level += 1
	target_xp *= TARGET_XP_GROWTH
	
	emit_signal("level_up", current_level)
	emit_signal("xp_gained", current_xp, target_xp) # Update bar for new level

func apply_upgrade(upgrade: Resource) -> void:
	print("Applied upgrade: %s" % upgrade.name)
	# TODO: Implement actual upgrade logic (stat changes)
