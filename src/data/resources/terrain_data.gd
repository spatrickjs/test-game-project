class_name TerrainData
extends Resource
## Logical terrain definition. Contains no rendering identifiers.

@export var terrain_type: SimulationEnums.TerrainType = SimulationEnums.TerrainType.DRY_SOIL
@export var display_name: String = ""
@export var is_plantable: bool = false
@export var allowed_crops: Array[SimulationEnums.CropType] = []


func validate() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if not SimulationEnums.TerrainType.values().has(terrain_type):
		errors.append("terrain_type has an invalid identifier.")
	if display_name.strip_edges().is_empty():
		errors.append("display_name must not be blank.")
	if not is_plantable and not allowed_crops.is_empty():
		errors.append("allowed_crops must be empty on unplantable terrain.")
	var seen_types: Array[SimulationEnums.CropType] = []
	for index: int in range(allowed_crops.size()):
		var crop_type: SimulationEnums.CropType = allowed_crops[index]
		if not SimulationEnums.CropType.values().has(crop_type):
			errors.append("allowed_crops[%d]: invalid crop identifier." % index)
		if seen_types.has(crop_type):
			errors.append("allowed_crops[%d]: duplicate crop identifier." % index)
		else:
			seen_types.append(crop_type)
	return errors


func copy() -> TerrainData:
	var result: TerrainData = TerrainData.new()
	result.terrain_type = terrain_type
	result.display_name = display_name
	result.is_plantable = is_plantable
	result.allowed_crops.assign(allowed_crops)
	return result
