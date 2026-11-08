extends SceneTree
## Exercise the authored game resources, not fitted biological behavior.

var failures: PackedStringArray = PackedStringArray()

func _initialize() -> void:
	var catalog: DiseaseDatabase = load("res://src/data/databases/default_disease_database.tres") as DiseaseDatabase
	for disease: DiseaseData in catalog.diseases:
		for algorithm: int in [0, 1, 2]:
			var first: String = _exercise(catalog, disease, algorithm)
			var repeat: String = _exercise(catalog, disease, algorithm)
			_check(first == repeat, "%s algorithm %d: seeded playtest repeats" % [disease.display_name, algorithm])
	for failure: String in failures:
		printerr("FAIL: " + failure)
	if failures.is_empty():
		print("PLAYABLE_DISEASE_CATALOG_PASS")
	quit(0 if failures.is_empty() else 1)

func _exercise(catalog: DiseaseDatabase, disease: DiseaseData, algorithm: int) -> String:
	var context: String = "%s algorithm %d" % [disease.display_name, algorithm]
	var farming: FarmingController = FarmingController.new()
	farming.crop_database = load("res://src/data/databases/crop_database.tres") as CropDatabase
	farming.terrain_database = load("res://src/data/databases/terrain_database.tres") as TerrainDatabase
	farming.initial_soil = SoilState.new()
	farming.initial_abiotic = AbioticState.new()
	farming.field_size = Vector2i(2, 1)
	farming.terrain_bands = [SimulationEnums.TerrainType.PADDY_MUD if disease.target_crop == SimulationEnums.CropType.RICE else SimulationEnums.TerrainType.DRY_SOIL]
	var turns: TurnController = TurnController.new()
	turns.farming_controller = farming
	turns.disease_database = catalog
	turns.simulation_controller.algorithm_override = algorithm
	turns.simulation_controller.rng.seed = 42
	var activation: DiseaseActivationController = DiseaseActivationController.new()
	activation.debug_introductions = false
	activation.policy = DiseaseActivationPolicy.new()
	activation.policy.allowed_disease_ids = [disease.disease_id]
	activation.policy.first_eligible_turn = 1
	activation.policy.chance_per_eligible_turn = 1.0
	activation.policy.max_introductions_per_session = 1
	turns.disease_activation_controller = activation
	turns.reset_clock()
	_check(farming.initialize_field(), context + ": field initializes")
	_check(farming.try_plant(Vector2i.ZERO, disease.target_crop) and farming.try_plant(Vector2i(1, 0), disease.target_crop), context + ": compatible crop planting")
	_check(turns.advance_turn(), context + ": automatic introduction succeeds: " + turns.last_error)
	var request: DiseaseActivationRequest = farming.last_turn_introduction
	if request == null:
		_check(false, context + ": introduction exists")
		activation.free()
		turns.free()
		farming.free()
		return ""
	_check(request.disease_id == disease.disease_id, context + ": requested identity selected")
	var neighbor: Vector2i = Vector2i(1 - request.coordinates.x, 0)
	_check(not farming.get_grid_snapshot().get_cell(neighbor).has_active_disease, context + ": no spread on introduction turn")
	_check(turns.advance_turn(), context + ": next turn succeeds with full catalog: " + turns.last_error)
	var snapshot: FieldGridState = farming.get_grid_snapshot()
	if algorithm == SimulationEnums.SimulationAlgorithm.SPATIAL_SIR:
		_check(snapshot.get_cell(neighbor).infected_fraction > 0.0, context + ": game spread occurs next turn")
	elif algorithm == SimulationEnums.SimulationAlgorithm.SPATIAL_SEIR:
		_check(snapshot.get_cell(neighbor).exposed_fraction > 0.0, context + ": game exposed stage occurs next turn")
	for step: int in range(3):
		_check(turns.advance_turn(), context + ": ongoing game progression: " + turns.last_error)
	snapshot = farming.get_grid_snapshot()
	_check(snapshot.validate().is_empty(), context + ": final board validates")
	_check(activation.get_state_snapshot().introductions_committed == 1, context + ": progression does not consume extra introductions")
	var signature: Array[String] = []
	for x: int in range(2):
		var cell: FieldCellState = snapshot.get_cell(Vector2i(x, 0))
		_check(not cell.has_active_disease or cell.active_disease_id == disease.disease_id, context + ": no competing identity introduced")
		if algorithm == SimulationEnums.SimulationAlgorithm.STOCHASTIC_CA_SIR:
			_check(CompartmentMath.one_hot_index(cell) >= 0, context + ": CA remains categorical")
		signature.append(str([cell.has_active_disease, cell.active_disease_id, cell.susceptible_fraction, cell.exposed_fraction, cell.infected_fraction, cell.recovered_immune_fraction, cell.dead_fraction]))
	activation.free()
	turns.free()
	farming.free()
	return "|".join(signature)

func _check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
