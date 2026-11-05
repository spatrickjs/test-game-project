@tool
class_name TerrainTileVisualMap
extends Resource

@export var entries: Array[TerrainTileVisual] = []


func get_visual(terrain_type: SimulationEnums.TerrainType) -> TerrainTileVisual:
	for entry: TerrainTileVisual in entries:
		if entry != null and entry.terrain_type == terrain_type:
			return entry
	return null


func validate(tile_set: TileSet) -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if tile_set == null:
		errors.append("Assign a TileSet to the Terrain TileMapLayer.")
		return errors
	var seen: Array[SimulationEnums.TerrainType] = []
	for index: int in range(entries.size()):
		var entry: TerrainTileVisual = entries[index]
		var prefix: String = "entries[%d]: " % index
		if entry == null:
			errors.append(prefix + "entry must not be null.")
			continue
		if not SimulationEnums.TerrainType.values().has(entry.terrain_type):
			errors.append(prefix + "invalid terrain_type.")
		if seen.has(entry.terrain_type):
			errors.append(prefix + "duplicate terrain_type.")
		else:
			seen.append(entry.terrain_type)
		if entry.source_id < 0 or not tile_set.has_source(entry.source_id):
			errors.append(prefix + "source_id does not exist in the TileSet.")
			continue
		var atlas: TileSetAtlasSource = tile_set.get_source(entry.source_id) as TileSetAtlasSource
		if atlas == null:
			errors.append(prefix + "source must be a TileSetAtlasSource.")
			continue
		if not atlas.has_tile(entry.atlas_coords):
			errors.append(prefix + "atlas_coords does not identify a tile.")
			continue
		if entry.alternative_tile < 0 or not atlas.has_alternative_tile(entry.atlas_coords, entry.alternative_tile):
			errors.append(prefix + "alternative_tile does not exist.")
	return errors
