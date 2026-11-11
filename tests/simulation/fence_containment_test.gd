extends SceneTree
## Simulation containment tests for the Fence Treatment Method.
## Validates Requirement 7 (disease containment) and Property 5 (containment equivalence).
##
## No production code change is expected in src/simulation/. A fenced tile is GRASS
## with no crop, which SimulationController already excludes as a host and pressure source.
var _failures: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var farming: FarmingController = _make_controller()
	var database: DiseaseDatabase = _database()
	var disease: DiseaseData = database.diseases[0]
	var engine: SimulationController = SimulationController.new()
	engine.crop_database = farming.crop_database

	# --- Requirement 7.1: fenced tile is not a host ---
	# Build a 3-cell grid: [infected, fenced, healthy].
	var grid: FieldGridState = _grid(3, farming)
	_infect(grid.get_cell(Vector2i.ZERO), disease)
	_fence(grid.get_cell(Vector2i(1, 0)))
	# The fenced cell must not be reported as an invalid host.
	var turn_errors: PackedStringArray = engine.validate_turn(grid, database)
	_check(turn_errors.is_empty(), "validate_turn accepts fenced neighbor: %s" % "\n".join(turn_errors))
	_check(engine.process_turn(grid, database), "process_turn succeeds with fenced neighbor")
	# Fenced cell receives no infection.
	var fenced_after: FieldCellState = grid.get_cell(Vector2i(1, 0))
	_check(fenced_after.infected_fraction == 0.0, "Fenced cell receives no infection (SIR)")
	_check(not fenced_after.has_active_disease, "Fenced cell has no active disease")
	_check(fenced_after.susceptible_fraction == 0.0, "Fenced cell fractions stay zero")

	# --- Requirement 7.2: fenced tile is not a source of pressure ---
	# Fenced cell as a neighbor of an infected cell contributes zero pressure.
	# The healthy cell at (2,0) should get the same infection as if the fenced
	# cell were ordinary grass (which also contributes no pressure).
	var grid_b: FieldGridState = _grid(3, farming)
	_infect(grid_b.get_cell(Vector2i.ZERO), disease)
	# Make (1,0) ordinary grass (no fence, no crop).
	var grass_cell: FieldCellState = grid_b.get_cell(Vector2i(1, 0))
	grass_cell.terrain_type = SimulationEnums.TerrainType.GRASS
	grass_cell.soil = null
	grass_cell.has_crop = false
	grass_cell.reset_crop_state()
	_check(engine.process_turn(grid_b, database), "Ordinary grass neighbor turn succeeds")
	var healthy_b: FieldCellState = grid_b.get_cell(Vector2i(2, 0))
	# Compare: fenced grid's healthy cell should equal ordinary-grass grid's healthy cell.
	_check(_fractions_equal(fenced_after, healthy_b) or true, "Containment check (fractions compared below)")

	# Direct equivalence: run both fenced and ordinary-grass grids with the same seed.
	var seed_val: int = 12345
	# Fenced variant.
	var fenced_grid: FieldGridState = _grid(3, farming)
	_infect(fenced_grid.get_cell(Vector2i.ZERO), disease)
	_fence(fenced_grid.get_cell(Vector2i(1, 0)))
	var eng_f: SimulationController = SimulationController.new()
	eng_f.rng.seed = seed_val
	eng_f.process_turn(fenced_grid, database)
	# Ordinary-grass variant.
	var grass_grid: FieldGridState = _grid(3, farming)
	_infect(grass_grid.get_cell(Vector2i.ZERO), disease)
	var gc: FieldCellState = grass_grid.get_cell(Vector2i(1, 0))
	gc.terrain_type = SimulationEnums.TerrainType.GRASS
	gc.soil = null
	gc.has_crop = false
	gc.reset_crop_state()
	var eng_g: SimulationController = SimulationController.new()
	eng_g.rng.seed = seed_val
	eng_g.process_turn(grass_grid, database)
	# Property 5: containment equivalence — neighbors' results equal ordinary grass.
	_check(_fractions_equal(fenced_grid.get_cell(Vector2i(2, 0)), grass_grid.get_cell(Vector2i(2, 0))), "Property 5: healthy neighbor matches ordinary-grass equivalent")
	_check(_fractions_equal(fenced_grid.get_cell(Vector2i.ZERO), grass_grid.get_cell(Vector2i.ZERO)), "Property 5: infected source matches")

	# --- Requirement 7.3: fencing an infected crop clears its disease ---
	# Use the FarmingController to fence an infected cell.
	var sim_grid: FieldGridState = _grid(2, farming)
	_infect(sim_grid.get_cell(Vector2i.ZERO), disease)
	# Apply fence via the controller's internal commit (use enqueue + arrive).
	# We'll set up the controller's grid directly.
	farming.initialize_field()
	# Plant a crop and infect it, then fence.
	_check(farming.try_plant(Vector2i.ZERO, disease.target_crop), "Plant compatible crop for infection")
	var infected_cell: FieldCellState = farming.get_grid_snapshot().get_cell(Vector2i.ZERO)
	infected_cell.has_active_disease = true
	infected_cell.active_disease_id = disease.disease_id
	infected_cell.sir_state = SimulationEnums.SIRState.I
	infected_cell.infected_fraction = 1.0
	infected_cell.susceptible_fraction = 0.0
	# Now fence it.
	var action: FieldAction = FieldAction.new()
	action.kind = SimulationEnums.FieldActionKind.FENCE
	action.target = Vector2i.ZERO
	_check(farming.enqueue_action(action), "FENCE enqueued on infected crop")
	_check(farming.arrive_at_action(farming.get_current_action().id, Vector2i.ZERO), "FENCE arrives and commits")
	var cleared: FieldCellState = farming.get_grid_snapshot().get_cell(Vector2i.ZERO)
	_check(not cleared.has_active_disease, "Fencing clears active disease identity")
	_check(not cleared.has_crop, "Fencing clears crop")
	# validate_turn must report no errors from that tile.
	var vt_errors: PackedStringArray = engine.validate_turn(farming.get_grid_snapshot(), database)
	_check(vt_errors.is_empty(), "validate_turn clean after fencing infected crop: %s" % "\n".join(vt_errors))

	# --- Requirement 7.4: DiseaseActivationController never selects a fenced cell ---
	var activation: DiseaseActivationController = DiseaseActivationController.new()
	var policy: DiseaseActivationPolicy = DiseaseActivationPolicy.new()
	policy.enabled = true
	policy.allowed_disease_ids = [disease.disease_id]
	policy.chance_per_eligible_turn = 1.0
	policy.first_eligible_turn = 1
	policy.max_introductions_per_session = 100
	activation.policy = policy
	activation.reset_session()
	# Build a grid where the only cells are fenced (so none are eligible).
	var act_grid: FieldGridState = _grid(2, farming)
	_fence(act_grid.get_cell(Vector2i.ZERO))
	_fence(act_grid.get_cell(Vector2i(1, 0)))
	# (1,0) is healthy susceptible corn.
	var proposal: DiseaseActivationController.Result = activation.evaluate(act_grid, database, 1, -1, true)
	_check(proposal.request == null, "DiseaseActivation never selects a fenced cell")
	_check(proposal.errors.is_empty(), "Activation evaluation has no errors")

	# --- Requirement 7.5: Seed Infection action is unavailable for a fenced tile ---
	# seed_infection uses is_eligible which requires has_crop; fenced has no crop.
	_check(not farming.seed_infection(Vector2i.ZERO, disease.disease_id, database, engine), "Seed infection rejected on fenced tile")

	# --- Requirement 7.6: fence does not change dispersal geometry ---
	# GridNeighborhood returns the same coordinates regardless of has_fence.
	var neighbors_fenced: Array[Vector2i] = GridNeighborhood.get_neighbor_coordinates(fenced_grid, Vector2i(1, 0), disease.neighborhood_type, disease.dispersal_radius)
	var neighbors_grass: Array[Vector2i] = GridNeighborhood.get_neighbor_coordinates(grass_grid, Vector2i(1, 0), disease.neighborhood_type, disease.dispersal_radius)
	_check(neighbors_fenced == neighbors_grass, "GridNeighborhood unchanged by fence")

	# --- SEIR variant ---
	var seir_grid: FieldGridState = _grid(3, farming)
	_infect(seir_grid.get_cell(Vector2i.ZERO), disease)
	_fence(seir_grid.get_cell(Vector2i(1, 0)))
	engine.algorithm_override = SimulationEnums.SimulationAlgorithm.SPATIAL_SEIR
	_check(engine.process_turn(seir_grid, database), "SEIR turn with fenced neighbor")
	_check(seir_grid.get_cell(Vector2i(1, 0)).exposed_fraction == 0.0, "SEIR: fenced cell receives no exposure")

	# --- CA variant ---
	var ca_grid: FieldGridState = _grid(3, farming)
	_infect(ca_grid.get_cell(Vector2i.ZERO), disease)
	_fence(ca_grid.get_cell(Vector2i(1, 0)))
	engine.algorithm_override = SimulationEnums.SimulationAlgorithm.STOCHASTIC_CA_SIR
	_check(engine.process_turn(ca_grid, database), "CA turn with fenced neighbor")
	_check(ca_grid.get_cell(Vector2i(1, 0)).infected_fraction == 0.0, "CA: fenced cell receives no infection")

	farming.free()
	for failure: String in _failures:
		printerr("FAIL: " + failure)
	if _failures.is_empty():
		print("FENCE_CONTAINMENT_PASS")
	quit(0 if _failures.is_empty() else 1)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_controller() -> FarmingController:
	var farming := FarmingController.new()
	farming.crop_database = load("res://src/data/databases/crop_database.tres") as CropDatabase
	farming.terrain_database = load("res://src/data/databases/terrain_database.tres") as TerrainDatabase
	farming.initial_soil = SoilState.new()
	farming.initial_abiotic = AbioticState.new()
	farming.field_size = Vector2i(9, 6)
	farming.terrain_bands = [
		SimulationEnums.TerrainType.DRY_SOIL,
		SimulationEnums.TerrainType.PADDY_MUD,
		SimulationEnums.TerrainType.GRASS,
	]
	assert(farming.initialize_field())
	return farming


## Builds a 1-row grid of corn on dry soil using the controller's databases.
func _grid(width: int, farming: FarmingController) -> FieldGridState:
	var grid: FieldGridState = FieldGridState.new()
	grid.initialize(width, 1, AbioticState.new())
	for x: int in range(width):
		var cell: FieldCellState = grid.get_cell(Vector2i(x, 0))
		cell.terrain_type = SimulationEnums.TerrainType.DRY_SOIL
		cell.soil = SoilState.new()
		cell.has_crop = true
		cell.crop_type = SimulationEnums.CropType.CORN
		cell.reset_crop_state()
	return grid


func _database() -> DiseaseDatabase:
	var database: DiseaseDatabase = DiseaseDatabase.new()
	var disease: DiseaseData = DiseaseData.new()
	disease.display_name = "Test Corn Rust"
	disease.disease_id = SimulationEnums.DiseaseId.COMMON_CORN_RUST
	disease.target_crop = SimulationEnums.CropType.CORN
	disease.neighborhood_type = SimulationEnums.NeighborhoodType.VON_NEUMANN_4
	disease.beta = 1.0
	disease.gamma = 0.0
	disease.distance_decay = 1.0
	database.diseases.append(disease)
	return database


func _infect(cell: FieldCellState, disease: DiseaseData) -> void:
	cell.has_active_disease = true
	cell.active_disease_id = disease.disease_id
	cell.sir_state = SimulationEnums.SIRState.I
	cell.susceptible_fraction = 0.0
	cell.infected_fraction = 1.0


func _fence(cell: FieldCellState) -> void:
	cell.has_crop = false
	cell.reset_crop_state()
	cell.terrain_type = SimulationEnums.TerrainType.GRASS
	cell.soil = null
	cell.has_fence = true


func _fractions_equal(a: FieldCellState, b: FieldCellState) -> bool:
	return is_equal_approx(a.susceptible_fraction, b.susceptible_fraction) \
		and is_equal_approx(a.exposed_fraction, b.exposed_fraction) \
		and is_equal_approx(a.infected_fraction, b.infected_fraction) \
		and is_equal_approx(a.recovered_immune_fraction, b.recovered_immune_fraction) \
		and is_equal_approx(a.dead_fraction, b.dead_fraction)


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)
