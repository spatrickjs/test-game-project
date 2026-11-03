class_name CropDatabase
extends Resource
## Inspector-authored catalog. Returned definitions are shared references;
## treat them as read-only during gameplay. Partial and empty catalogs are valid.

@export var crops: Array[CropData] = []


## Returns the first matching non-null entry, or null for missing/invalid IDs.
func get_crop(crop_type: SimulationEnums.CropType) -> CropData:
	if not SimulationEnums.CropType.values().has(crop_type):
		return null
	for crop: CropData in crops:
		if crop != null and crop.crop_type == crop_type:
			return crop
	return null


func has_crop(crop_type: SimulationEnums.CropType) -> bool:
	return get_crop(crop_type) != null


## Reports all errors without modifying the catalog or its definitions.
func validate() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	var seen_types: Array[SimulationEnums.CropType] = []
	for index: int in range(crops.size()):
		var crop: CropData = crops[index]
		if crop == null:
			errors.append("crops[%d]: entry must not be null." % index)
			continue
		if seen_types.has(crop.crop_type):
			errors.append("crops[%d]: duplicate crop_type registration %d." % [index, crop.crop_type])
		else:
			seen_types.append(crop.crop_type)
		for error: String in crop.validate():
			errors.append("crops[%d]: %s" % [index, error])
	return errors
