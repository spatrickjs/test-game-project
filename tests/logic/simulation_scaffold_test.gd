extends SceneTree


class Probe:
	extends SimulationController
	var calls: int = 0
	var evaluated: int = 0
	var neighbor_count: int = 0
	var observed_growth: int = -1

	func process_turn(grid_state: FieldGridState, diseases: DiseaseDatabase) -> bool:
		calls += 1
		observed_growth = grid_state.get_cell(Vector2i.ZERO).growth_elapsed_ticks
		return super.process_turn(grid_state, diseases)

	func _evaluate_cell(cell_state: FieldCellState, disease: DiseaseData, neighbors: Array[FieldCellState], environment: AbioticState) -> FieldCellState:
		evaluated += 1
		neighbor_count = neighbors.size()
		return super._evaluate_cell(cell_state, disease, neighbors, environment)


var failures: int = 0


func _initialize() -> void:
	var farming: FarmingController = FarmingController.new()
	farming.crop_database = load("res://src/data/databases/crop_database.tres") as CropDatabase
	farming.terrain_database = load("res://src/data/databases/terrain_database.tres") as TerrainDatabase
	farming.initial_soil = SoilState.new()
	farming.initial_abiotic = AbioticState.new()
	check(farming.initialize_field(), "Initialize")
	check(farming.try_plant(Vector2i.ZERO, SimulationEnums.CropType.SUGARCANE), "Plant")
	var turns: TurnController = TurnController.new()
	var probe: Probe = Probe.new()
	turns.farming_controller = farming
	turns.simulation_controller = probe
	turns.turn_completed.connect(func(index: int) -> void:
		check(index == 1 and probe.calls == 1 and probe.observed_growth == 1, "Growth -> Simulation -> UI")
	)
	check(turns.advance_turn(), "Empty catalog turn")
	check(probe.evaluated == 0, "Empty catalog skips evaluation")
	var disease: DiseaseData = DiseaseData.new()
	disease.display_name = "Test RSSI"
	turns.disease_database.diseases.append(disease)
	probe.process_turn(farming.get_grid_snapshot(), turns.disease_database)
	check(probe.evaluated == 1 and probe.neighbor_count == 3, "Healthy corner Moore neighbors")
	disease.neighborhood_type = SimulationEnums.NeighborhoodType.VON_NEUMANN_4
	probe.process_turn(farming.get_grid_snapshot(), turns.disease_database)
	check(probe.neighbor_count == 2, "Corner orthogonal neighbors")
	var cell: FieldCellState = farming.get_grid_snapshot().get_cell(Vector2i.ZERO)
	check(cell.susceptible_fraction == 1.0, "Stub preserves compartments")
	check(farming.clear_crop(Vector2i.ZERO), "Clear")
	cell = farming.get_grid_snapshot().get_cell(Vector2i.ZERO)
	check(not cell.has_crop and cell.susceptible_fraction == 0.0 and cell.validate().is_empty(), "Clear resets valid empty state")
	check(farming.try_plant(Vector2i.ZERO, SimulationEnums.CropType.SUGARCANE), "Replant")
	cell = farming.get_grid_snapshot().get_cell(Vector2i.ZERO)
	check(cell.susceptible_fraction == 1.0 and cell.growth_elapsed_ticks == 0, "Replant resets healthy state")
	turns.disease_database.diseases.append(null)
	check(not turns.advance_turn(), "Invalid catalog rejected before growth")
	check(farming.get_grid_snapshot().get_cell(Vector2i.ZERO).growth_elapsed_ticks == 0, "No partial growth on invalid catalog")
	turns.disease_database.diseases.resize(1)
	var authoritative: FieldGridState = farming.get("_grid") as FieldGridState
	var latent: FieldCellState = authoritative.get_cell(Vector2i.ZERO)
	latent.has_active_disease = true
	latent.susceptible_fraction = 0.5
	latent.exposed_fraction = 0.5
	probe.algorithm_override = SimulationEnums.SimulationAlgorithm.SPATIAL_SIR
	check(not turns.advance_turn(), "Incompatible switch rejected by turn controller")
	check(latent.growth_elapsed_ticks == 0 and turns.turn_index == 1 and probe.calls == 3, "Rejected switch neither grows nor invokes simulation nor emits UI")
	turns.free()
	farming.free()
	if failures == 0:
		print("SIMULATION_SCAFFOLD_PASS")
	quit(0 if failures == 0 else 1)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)
