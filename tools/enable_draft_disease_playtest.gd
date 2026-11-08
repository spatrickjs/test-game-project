@tool
extends EditorScript
## Explicit one-time authoring: assign one fictional preset to the eight new drafts.
## Rerunning intentionally overwrites their model settings; do not run after individual tuning.

func _run() -> void:
	await run_setup()

func run_setup() -> int:
	var tree: SceneTree = EditorInterface.get_base_control().get_tree()
	for frame: int in range(10):
		await tree.process_frame
	while EditorInterface.get_resource_filesystem().is_scanning():
		await tree.process_frame
	var catalog: Resource = load("res://src/data/databases/default_disease_database.tres")
	var policy_path: String = "res://src/data/resources/disease_activation/default_activation_policy.tres"
	var policy: Resource = load(policy_path)
	if catalog == null or policy == null:
		return 1
	var entries: Array = catalog.get("diseases")
	if entries.size() != SimulationEnums.DiseaseId.size():
		push_error("Create the complete catalog before enabling the playtest.")
		return 1
	var allowed: Array[SimulationEnums.DiseaseId] = []
	# These values are an identical toy-game preset for every new entry.
	# No real-world measurements, transmission routes or environmental triggers are inferred.
	var preset: Dictionary[StringName, Variant] = {
		&"default_algorithm": SimulationEnums.SimulationAlgorithm.SPATIAL_SIR,
		&"beta": 0.35, &"sigma": 0.3, &"gamma": 0.1, &"xi": 0.0,
		&"mortality_probability": 0.0,
		&"neighborhood_type": SimulationEnums.NeighborhoodType.MOORE_8,
		&"dispersal_radius": 1, &"distance_decay": 0.0,
		&"transmission_modifier_profile": null,
	}
	for entry: Resource in entries:
		if entry == null or entry.resource_path.contains("::") or not entry.resource_path.begins_with("res://src/data/resources/diseases/"):
			push_error("Catalog entries must reference standalone disease resources.")
			return 1
		var disease_id: SimulationEnums.DiseaseId = entry.get("disease_id") as SimulationEnums.DiseaseId
		if allowed.has(disease_id):
			return 1
		allowed.append(disease_id)
		if disease_id == SimulationEnums.DiseaseId.RICE_BLAST:
			continue
		for property: StringName in preset:
			entry.set(property, preset[property])
		var abiotic_rules: Array[AbioticRule] = []
		var nutrient_rules: Array[NutrientRule] = []
		entry.set("abiotic_trigger_rules", abiotic_rules)
		entry.set("nutrient_susceptibility_rules", nutrient_rules)
		entry.set_meta("authoring_status", "Playable draft; temporary fictional game settings; expert/model review pending.")
		entry.set_meta("calibration", "Shared toy-game preset v1, identical for all eight new drafts. Not estimated from interviews or calibrated to real-world disease behavior.")
		entry.set_meta("gameplay_preset", "temporary_shared_v1")
		entry.set_meta("finalization_notes", "See res://docs/DISEASE_FINALIZATION.md. Review content, model suitability, gameplay outcomes, parameters and evaluation before removing draft status.")
		if disease_id == SimulationEnums.DiseaseId.RSSI:
			entry.set_meta("model_review", "Insect pest represented temporarily by the same abstract compartment game rules. No insect lifecycle or pest-specific dynamics are implemented; do not interpret recovery as a validated pest-management outcome.")
		if ResourceSaver.save(entry, entry.resource_path) != OK:
			return 1
	allowed.sort()
	policy.set("allowed_disease_ids", allowed)
	if ResourceSaver.save(policy, policy_path) != OK:
		return 1
	print("DRAFT_DISEASE_PLAYTEST_SETUP_PASS")
	return 0
