class_name HarvestResult
extends RefCounted
## Detached receipt; no inventory or currency is granted by harvesting.
var success: bool = false
var reason: String = ""
var coordinates: Vector2i = Vector2i(-1, -1)
var crop_type: SimulationEnums.CropType = SimulationEnums.CropType.SUGARCANE
var quality_multiplier: float = 0.0
var base_score: int = 0
var score: float = 0.0
