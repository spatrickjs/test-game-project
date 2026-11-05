@tool
class_name TerrainTileVisual
extends Resource
## Rendering identifiers only; never used for planting or simulation decisions.

@export var terrain_type: SimulationEnums.TerrainType = SimulationEnums.TerrainType.DRY_SOIL
@export var source_id: int = -1
@export var atlas_coords: Vector2i = Vector2i.ZERO
@export var alternative_tile: int = 0
