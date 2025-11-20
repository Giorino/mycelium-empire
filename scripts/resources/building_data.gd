class_name BuildingData
extends Resource

@export var id: String
@export var name: String
@export_multiline var description: String
@export var icon: Texture2D
@export var scene: PackedScene
@export var nutrient_cost: int = 50
@export var growth_time: float = 5.0
