class_name DiseaseDatabase
extends Resource
## Inspector-authored catalog. Returned definitions are shared references;
## treat them as read-only during gameplay. Partial and empty catalogs are valid.

@export var diseases: Array[DiseaseData] = []


## Returns the first matching non-null entry, or null for missing/invalid IDs.
func get_disease(disease_id: SimulationEnums.DiseaseId) -> DiseaseData:
	if not SimulationEnums.DiseaseId.values().has(disease_id):
		return null
	for disease: DiseaseData in diseases:
		if disease != null and disease.disease_id == disease_id:
			return disease
	return null


## Returns a new array in catalog order, retaining shared Resource references.
## Nulls are skipped; duplicates remain visible. Invalid crop IDs return empty.
func get_diseases_for_crop(crop_type: SimulationEnums.CropType) -> Array[DiseaseData]:
	var matches: Array[DiseaseData] = []
	if not SimulationEnums.CropType.values().has(crop_type):
		return matches
	for disease: DiseaseData in diseases:
		if disease != null and disease.target_crop == crop_type:
			matches.append(disease)
	return matches


## Reports all errors without modifying the catalog or its definitions.
func validate() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	var seen_ids: Array[SimulationEnums.DiseaseId] = []
	for index: int in range(diseases.size()):
		var disease: DiseaseData = diseases[index]
		if disease == null:
			errors.append("diseases[%d]: entry must not be null." % index)
			continue
		if seen_ids.has(disease.disease_id):
			errors.append("diseases[%d]: duplicate disease_id registration %d." % [index, disease.disease_id])
		else:
			seen_ids.append(disease.disease_id)
		for error: String in disease.validate():
			errors.append("diseases[%d]: %s" % [index, error])
	return errors
