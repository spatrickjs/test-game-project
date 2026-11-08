@tool
extends EditorScript
## Adds missing catalog identities only. Existing definitions and activation policy are preserved.

func _run() -> void:
	await run_setup()

func run_setup() -> int:
	var tree: SceneTree = EditorInterface.get_base_control().get_tree()
	for frame: int in range(10):
		await tree.process_frame
	while EditorInterface.get_resource_filesystem().is_scanning():
		await tree.process_frame
	var catalog_path: String = "res://src/data/databases/default_disease_database.tres"
	var catalog: Resource = load(catalog_path)
	if catalog == null:
		return 1
	var entries: Array = catalog.get("diseases")
	var definitions: Array[Dictionary] = [
		{"id": SimulationEnums.DiseaseId.RSSI, "name": "Red-Striped Soft Scale Insect", "file": "red_striped_soft_scale_insect", "crop": SimulationEnums.CropType.SUGARCANE},
		{"id": SimulationEnums.DiseaseId.SUGARCANE_SMUT, "name": "Sugarcane Smut", "file": "sugarcane_smut", "crop": SimulationEnums.CropType.SUGARCANE},
		{"id": SimulationEnums.DiseaseId.LEAF_SCALD, "name": "Leaf Scald", "file": "leaf_scald", "crop": SimulationEnums.CropType.SUGARCANE},
		{"id": SimulationEnums.DiseaseId.RICE_TUNGRO, "name": "Rice Tungro", "file": "rice_tungro", "crop": SimulationEnums.CropType.RICE},
		{"id": SimulationEnums.DiseaseId.BACTERIAL_LEAF_BLIGHT, "name": "Bacterial Leaf Blight", "file": "bacterial_leaf_blight", "crop": SimulationEnums.CropType.RICE},
		{"id": SimulationEnums.DiseaseId.COMMON_CORN_RUST, "name": "Common Corn Rust", "file": "common_corn_rust", "crop": SimulationEnums.CropType.CORN},
		{"id": SimulationEnums.DiseaseId.PHILIPPINE_DOWNY_MILDEW, "name": "Philippine Downy Mildew", "file": "philippine_downy_mildew", "crop": SimulationEnums.CropType.CORN},
		{"id": SimulationEnums.DiseaseId.EAR_ROT, "name": "Ear Rot", "file": "ear_rot", "crop": SimulationEnums.CropType.CORN},
	]
	for definition: Dictionary in definitions:
		var path: String = "res://src/data/resources/diseases/%s.tres" % definition["file"]
		var entry: Resource
		if ResourceLoader.exists(path):
			entry = load(path)
		else:
			var draft: DiseaseData = DiseaseData.new()
			draft.disease_id = definition["id"] as SimulationEnums.DiseaseId
			draft.display_name = "%s (draft)" % definition["name"]
			draft.target_crop = definition["crop"] as SimulationEnums.CropType
			draft.set_meta("authoring_status", "Draft identity; not enabled for automatic introduction.")
			draft.set_meta("calibration", "Zero-valued model rates are unconfigured placeholders, not measured estimates. No disease-specific trigger rules have been authored.")
			draft.set_meta("category", "insect_pest" if draft.disease_id == SimulationEnums.DiseaseId.RSSI else "disease")
			if draft.disease_id == SimulationEnums.DiseaseId.RSSI:
				draft.set_meta("model_review", "RSSI means Red-Striped Soft Scale Insect. Retains the legacy DiseaseId for compatibility; pest behavior is not implemented or validated by this resource.")
			if not draft.validate().is_empty() or ResourceSaver.save(draft, path) != OK:
				return 1
			entry = load(path)
			EditorInterface.get_resource_filesystem().update_file(path)
		if entry.get("disease_id") != definition["id"] or entry.get("target_crop") != definition["crop"]:
			push_error("Existing resource identity conflicts with catalog entry: " + path)
			return 1
		var registered: bool = false
		for index: int in range(entries.size()):
			var existing: Resource = entries[index]
			if existing != null and existing.get("disease_id") == definition["id"]:
				registered = true
				# Repair identical embedded drafts produced by the initial setup only.
				if existing.resource_path.begins_with(catalog_path + "::") and _same_draft(existing, entry):
					entries[index] = entry
					continue
				if existing.resource_path != path:
					push_error("Disease ID already belongs to another resource: " + str(definition["id"]))
					return 1
		if not registered:
			entries.append(entry)
	catalog.set("diseases", entries)
	if ResourceSaver.save(catalog, catalog_path) != OK:
		return 1
	EditorInterface.get_resource_filesystem().update_file(catalog_path)
	print("DISEASE_CATALOG_SETUP_PASS")
	return 0

func _same_draft(left: Resource, right: Resource) -> bool:
	if not left.has_meta("authoring_status") or left.get_meta("authoring_status") != right.get_meta("authoring_status", ""):
		return false
	for property: StringName in [&"disease_id", &"display_name", &"target_crop", &"default_algorithm", &"beta", &"sigma", &"gamma", &"xi", &"mortality_probability", &"neighborhood_type", &"dispersal_radius", &"distance_decay", &"transmission_modifier_profile", &"abiotic_trigger_rules", &"nutrient_susceptibility_rules"]:
		if left.get(property) != right.get(property):
			return false
	return true
