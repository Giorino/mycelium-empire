class_name BuildingData
extends Resource

@export var id: String
@export var name: String
@export_multiline var description: String
@export var icon: Texture2D
@export var scene: PackedScene
@export var nutrient_cost: int = 50
@export var nutrient_generation_rate: int = 0 # Nutrients per second
@export var storage_capacity: int = 0 # Increases max nutrients
@export var build_limit: int = -1 # -1 for infinite, 1 for unique
@export var growth_time: float = 5.0
