@tool
extends EditorScript
## Creates missing demo resources, bakes UI, wires exports and saves via Godot.
## Existing authored disease/catalog resources are validated, never overwritten.

const DISEASE_PATH: String = "res://src/data/resources/diseases/rice_blast.tres"
const DATABASE_PATH: String = "res://src/data/databases/default_disease_database.tres"
const SCENE_PATH: String = "res://field_prototype.tscn"
const Baker: Script = preload("res://tools/bake_ui_to_scene.gd")


func _run() -> void:
	await run_setup()


func run_setup() -> int:
	var tree: SceneTree = EditorInterface.get_base_control().get_tree()
	EditorInterface.open_scene_from_path(SCENE_PATH)
	for frame: int in range(5):
		await tree.process_frame
	var scene: Node = EditorInterface.get_edited_scene_root()
	if scene == null or scene.scene_file_path != SCENE_PATH:
		return _fail("Open the prototype scene first.")
	var disease: DiseaseData = null
	if ResourceLoader.exists(DISEASE_PATH):
		disease = load(DISEASE_PATH) as DiseaseData
	else:
		if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DISEASE_PATH.get_base_dir())) != OK:
			return _fail("Could not create disease resource directory.")
		disease = DiseaseData.new()
		disease.disease_id = SimulationEnums.DiseaseId.RICE_BLAST
		disease.target_crop = SimulationEnums.CropType.RICE
		disease.display_name = "Rice Blast (playtest)"
		disease.beta = 0.6
		disease.sigma = 0.5
		disease.gamma = 0.15
		disease.xi = 0.0
		disease.mortality_probability = 0.1
		disease.neighborhood_type = SimulationEnums.NeighborhoodType.MOORE_8
		disease.dispersal_radius = 1
		disease.distance_decay = 0.3
		disease.transmission_modifier_profile = TransmissionModifierProfile.new()
		disease.transmission_modifier_profile.temperature_enabled = true
		disease.transmission_modifier_profile.humidity_sensitivity = 0.5
		disease.set_meta("calibration", "Illustrative playtest parameters; not empirically calibrated.")
		if ResourceSaver.save(disease, DISEASE_PATH) != OK:
			return _fail("Could not save disease.")
		disease.take_over_path(DISEASE_PATH)
	if disease == null or not (_validation_copy(disease) as DiseaseData).validate().is_empty() or disease.disease_id != SimulationEnums.DiseaseId.RICE_BLAST:
		return _fail("Existing rice_blast resource is invalid; left unchanged.")
	var database: DiseaseDatabase = null
	if ResourceLoader.exists(DATABASE_PATH):
		database = load(DATABASE_PATH) as DiseaseDatabase
	else:
		database = DiseaseDatabase.new()
		database.diseases.append(disease)
		if ResourceSaver.save(database, DATABASE_PATH) != OK:
			return _fail("Could not save catalog.")
		database.take_over_path(DATABASE_PATH)
	var checked_database: DiseaseDatabase = _validation_copy(database) as DiseaseDatabase if database != null else null
	if checked_database == null or not checked_database.validate().is_empty() or checked_database.get_disease(SimulationEnums.DiseaseId.RICE_BLAST) == null:
		return _fail("Existing catalog must contain valid Rice Blast; left unchanged.")
	var baker: EditorScript = Baker.new() as EditorScript
	baker._run()
	var inspector: Node = scene.get("tile_inspector") as Node
	var turns: Node = scene.get("turn_controller") as Node
	var selector: OptionButton = scene.get("algorithm_selector") as OptionButton
	if inspector == null or turns == null or selector == null or inspector.get("seed_infection_button") == null:
		return _fail("UI bake failed; scene was not saved.")
	turns.set("disease_database", database)
	inspector.set("disease_database", database)
	scene.set("playtest_disease_id", SimulationEnums.DiseaseId.RICE_BLAST)
	var uid_before: int = ResourceLoader.get_resource_uid(SCENE_PATH)
	EditorInterface.mark_scene_as_unsaved()
	# Dummy headless renderer cannot generate scene thumbnails.
	EditorInterface.save_scene_as(SCENE_PATH, false)
	if ResourceLoader.get_resource_uid(SCENE_PATH) != uid_before:
		return _fail("Unexpected scene UID change.")
	print("DISEASE_PLAYTEST_SETUP_PASS")
	return 0


func _fail(message: String) -> int:
	push_error(message)
	return 1


## Loaded non-tool Resources are placeholders in the editor. Build transient
## script instances for validation without changing the authored resources.
func _validation_copy(source: Resource) -> Resource:
	var script: Script = source.get_script() as Script
	if script == null:
		return source
	var result: Resource = script.new() as Resource
	for property: Dictionary in result.get_property_list():
		var property_name: StringName = property["name"]
		if property_name == &"script" or not (int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var value: Variant = source.get(property_name)
		if value is Resource:
			value = _validation_copy(value as Resource)
		elif value is Array:
			var array: Array = (value as Array).duplicate()
			for index: int in range(array.size()):
				if array[index] is Resource:
					array[index] = _validation_copy(array[index] as Resource)
			value = array
		result.set(property_name, value)
	return result
