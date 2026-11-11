class_name DiseaseVisualSet
extends Resource
## Per-disease crop visual configuration (presentation only).
## Bundles TileSet source IDs and atlas coordinates for one disease across
## all four growth stages. Add as many as needed to CropData.disease_visuals.
## Logic and Simulation must not interpret these TileSet identifiers.

@export var disease_id: SimulationEnums.DiseaseId = SimulationEnums.DiseaseId.RSSI

## Seedling, Vegetative, Reproductive, Mature.
## -1 means not authored for this stage (falls back to the generic diseased
## look in CropData, then to the healthy sprite).
@export var stage_source_ids: Array[int] = [-1, -1, -1, -1]
@export var stage_atlas_coords: Array[Vector2i] = [Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO]


## Reports invalid configuration without mutation.
func validate() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if not SimulationEnums.DiseaseId.values().has(disease_id):
		errors.append("disease_id has an invalid identifier.")
	if stage_source_ids.size() != 4:
		errors.append("stage_source_ids must contain four entries.")
	if stage_atlas_coords.size() != 4:
		errors.append("stage_atlas_coords must contain four entries.")
	return errors


## Deep-copies schema values.
func copy() -> DiseaseVisualSet:
	var result: DiseaseVisualSet = DiseaseVisualSet.new()
	result.disease_id = disease_id
	result.stage_source_ids = stage_source_ids.duplicate()
	result.stage_atlas_coords = stage_atlas_coords.duplicate()
	return result
