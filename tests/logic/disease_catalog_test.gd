extends SceneTree

func _initialize() -> void:
	var errors: PackedStringArray = PackedStringArray()
	var catalog: DiseaseDatabase = load("res://src/data/databases/default_disease_database.tres") as DiseaseDatabase
	var policy: DiseaseActivationPolicy = load("res://src/data/resources/disease_activation/default_activation_policy.tres") as DiseaseActivationPolicy
	if catalog == null or policy == null:
		printerr("FAIL: Saved catalog and policy must load")
		quit(1)
		return
	errors.append_array(catalog.validate())
	errors.append_array(policy.validate())
	if catalog.diseases.size() != SimulationEnums.DiseaseId.size():
		errors.append("Catalog must register every existing ID exactly once.")
	for raw_id: int in SimulationEnums.DiseaseId.values():
		var disease_id: SimulationEnums.DiseaseId = raw_id as SimulationEnums.DiseaseId
		var entry: DiseaseData = catalog.get_disease(disease_id)
		if entry == null:
			errors.append("Missing catalog ID %d." % raw_id)
			continue
		if not entry.resource_path.begins_with("res://src/data/resources/diseases/") or entry.resource_path.contains("::") or not entry.copy().validate().is_empty():
			errors.append("Definition %d must be a valid external resource." % raw_id)
		elif load(entry.resource_path) != entry:
			errors.append("Definition %d must reference its standalone file, not an embedded copy." % raw_id)
		if disease_id == SimulationEnums.DiseaseId.RICE_BLAST:
			continue
		if not entry.display_name.ends_with("(draft)") or not entry.has_meta("authoring_status"):
			errors.append("New entry %d must identify its draft status." % raw_id)
		if not policy.allowed_disease_ids.has(disease_id):
			errors.append("Playable draft %d must be allowed for automatic activation." % raw_id)
		if entry.beta <= 0.0 or entry.sigma <= 0.0 or entry.gamma <= 0.0:
			errors.append("Playable draft %d needs configured game progression." % raw_id)
		if entry.get_meta("gameplay_preset", "") != "temporary_shared_v1" or entry.transmission_modifier_profile != null or not entry.abiotic_trigger_rules.is_empty() or not entry.nutrient_susceptibility_rules.is_empty():
			errors.append("Playable draft %d must identify its generic preset and omit disease-specific trigger rules." % raw_id)
	var pest: DiseaseData = catalog.get_disease(SimulationEnums.DiseaseId.RSSI)
	if pest == null or pest.get_meta("category", "") != "insect_pest" or not pest.display_name.begins_with("Red-Striped Soft Scale Insect"):
		errors.append("RSSI must retain its clarified pest identity.")
	if policy.allowed_disease_ids.size() != SimulationEnums.DiseaseId.size():
		errors.append("The saved policy must allow all nine catalog IDs.")
	for error: String in errors:
		printerr("FAIL: " + error)
	if errors.is_empty():
		print("DISEASE_CATALOG_PASS")
	quit(0 if errors.is_empty() else 1)
