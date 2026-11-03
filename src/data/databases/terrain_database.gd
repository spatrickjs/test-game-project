class_name TerrainDatabase
extends Resource
## Partial catalogs are valid. Returned definitions are shared references.

@export var terrains: Array[TerrainData] = []


func get_terrain(terrain_type: SimulationEnums.TerrainType) -> TerrainData:
	if not SimulationEnums.TerrainType.values().has(terrain_type):
		return null
	for terrain: TerrainData in terrains:
		if terrain != null and terrain.terrain_type == terrain_type:
			return terrain
	return null


func has_terrain(terrain_type: SimulationEnums.TerrainType) -> bool:
	return get_terrain(terrain_type) != null


func validate() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	var seen_types: Array[SimulationEnums.TerrainType] = []
	for index: int in range(terrains.size()):
		var terrain: TerrainData = terrains[index]
		if terrain == null:
			errors.append("terrains[%d]: entry must not be null." % index)
			continue
		if seen_types.has(terrain.terrain_type):
			errors.append("terrains[%d]: duplicate terrain_type registration." % index)
		else:
			seen_types.append(terrain.terrain_type)
		for error: String in terrain.validate():
			errors.append("terrains[%d]: %s" % [index, error])
	return errors
