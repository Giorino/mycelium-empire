class_name MotherEgg
extends BaseBuilding

## The heart of the colony. If destroyed, game over.

@export var minion_cost: int = 50

var minion_manager: MinionManager
var mycelium_manager: MyceliumManager

func _ready() -> void:
	max_health = 500 # Stronger than normal buildings
	super._ready()
	
	# Locate managers safely using the "cave_world" group
	var cave_world = get_tree().get_first_node_in_group("cave_world")
	if cave_world:
		if cave_world.has_node("MinionManager"):
			minion_manager = cave_world.get_node("MinionManager")
		else:
			push_error("MotherEgg: CaveWorld found, but MinionManager node missing!")
			
		if cave_world.has_node("MyceliumManager"):
			mycelium_manager = cave_world.get_node("MyceliumManager")
		else:
			push_error("MotherEgg: CaveWorld found, but MyceliumManager node missing!")
	else:
		push_error("MotherEgg: CaveWorld NOT FOUND in group 'cave_world'!")
		# Fallback to absolute path
		minion_manager = get_node_or_null("/root/Main/CaveWorld/MinionManager")
		mycelium_manager = get_node_or_null("/root/Main/CaveWorld/MyceliumManager")

func _die() -> void:
	print("MOTHER EGG DESTROYED! GAME OVER!")
	# TODO: Trigger actual game over sequence
	# For now, just restart scene or show message
	get_tree().reload_current_scene()

## Attempt to spawn a minion
func spawn_minion() -> bool:
	print("MotherEgg: Attempting to spawn minion...")
	
	if not minion_manager:
		print("MotherEgg: MinionManager is null!")
		return false
	if not mycelium_manager:
		print("MotherEgg: MyceliumManager is null!")
		return false
		
	# Check minion limit
	var current_count = minion_manager.active_minions.size()
	var max_count = minion_manager.max_minions
	print("MotherEgg: Current minions: %d, Max: %d" % [current_count, max_count])
	
	if current_count >= max_count:
		print("MotherEgg: Max minions reached! Cannot spawn.")
		return false
		
	# Try to spend nutrients
	print("MotherEgg: Trying to spend %d nutrients (Have: %d)" % [minion_cost, mycelium_manager.current_nutrients])
	if mycelium_manager.try_spend_nutrients(minion_cost):
		print("MotherEgg: Nutrients spent. Spawning minion...")
		# Spawn minion near egg
		var spawn_pos = position + Vector2(randf_range(-30, 30), randf_range(-30, 30))
		var minion = minion_manager.spawn_minion(spawn_pos)
		if minion:
			print("MotherEgg: Minion spawned successfully!")
			return true
		else:
			print("MotherEgg: MinionManager returned null for spawned minion!")
			return false
		
	print("MotherEgg: Not enough nutrients!")
	return false
