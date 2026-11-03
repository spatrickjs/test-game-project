extends SceneTree

var failures: int = 0


class BrokenModel:
	extends SimulationController

	func _evaluate_cell(cell: FieldCellState, disease: DiseaseData, neighbors: Array[FieldCellState], environment: AbioticState) -> FieldCellState:
		var next: FieldCellState = super._evaluate_cell(cell, disease, neighbors, environment)
		rng.randf()
		if cell.coordinates.x == 1:
			next.infected_fraction = NAN
		return next


func _initialize() -> void:
	var database: DiseaseDatabase = _database()
	var disease: DiseaseData = database.diseases[0]
	var engine: SimulationController = SimulationController.new()
	var grid: FieldGridState = _grid(3)
	_infect(grid.get_cell(Vector2i.ZERO))
	disease.beta = 1.0
	disease.gamma = 1.0
	check(engine.process_turn(grid, database), "SIR evaluation")
	var middle: FieldCellState = grid.get_cell(Vector2i(1, 0))
	check(is_equal_approx(middle.infected_fraction, 1.0 - exp(-1.0)), "SIR bounded infection flux")
	check(grid.get_cell(Vector2i(2, 0)).infected_fraction == 0.0, "No same-turn infection chain")
	check(is_equal_approx(middle.recovered_immune_fraction, 0.0), "New infection cannot recover this turn")
	check(is_equal_approx(grid.get_cell(Vector2i.ZERO).infected_fraction, exp(-1.0)), "Removal uses old I")
	_check_fractions(grid)

	# A reflected field must reflect the continuous outcome (no directional bias).
	var left: FieldGridState = _grid(5)
	var right: FieldGridState = _grid(5)
	_infect(left.get_cell(Vector2i.ZERO))
	_infect(right.get_cell(Vector2i(4, 0)))
	for tick: int in range(8):
		check(engine.process_turn(left, database) and engine.process_turn(right, database), "Mirror turns")
		for x: int in range(5):
			var a: Array[float] = CompartmentMath.fractions(left.get_cell(Vector2i(x, 0)))
			var b: Array[float] = CompartmentMath.fractions(right.get_cell(Vector2i(4 - x, 0)))
			for i: int in range(5):
				check(is_equal_approx(a[i], b[i]), "Reflection invariant")

	engine.algorithm_override = SimulationEnums.SimulationAlgorithm.SPATIAL_SEIR
	grid = _grid(2)
	_infect(grid.get_cell(Vector2i.ZERO))
	disease.sigma = 2.0
	check(engine.process_turn(grid, database), "SEIR evaluation")
	middle = grid.get_cell(Vector2i(1, 0))
	check(middle.exposed_fraction > 0.0 and middle.infected_fraction == 0.0, "SEIR latent delay")
	var prior_e: float = middle.exposed_fraction
	check(engine.process_turn(grid, database), "SEIR incubation")
	check(is_equal_approx(middle.infected_fraction, prior_e * (1.0 - exp(-2.0))), "SEIR incubation uses old E")
	engine.algorithm_override = SimulationEnums.SimulationAlgorithm.SPATIAL_SIR
	var before: Array[float] = CompartmentMath.fractions(middle)
	var rng_before: int = engine.rng.state
	check(not engine.process_turn(grid, database), "Reject SEIR -> SIR with E")
	check(before == CompartmentMath.fractions(middle) and engine.rng.state == rng_before, "Rejection is atomic")
	engine.algorithm_override = SimulationEnums.SimulationAlgorithm.STOCHASTIC_CA_SIR
	check(not engine.process_turn(grid, database), "Reject E entering CA")

	grid = _grid(2)
	_infect(grid.get_cell(Vector2i.ZERO))
	engine.algorithm_override = SimulationEnums.SimulationAlgorithm.SPATIAL_SIR
	check(engine.process_turn(grid, database), "Create mixed fractions")
	engine.algorithm_override = SimulationEnums.SimulationAlgorithm.STOCHASTIC_CA_SIR
	check(not engine.process_turn(grid, database), "CA rejects fractional stands")

	# Exact one-hot state can switch across all three algorithms without projection.
	grid = _grid(2)
	_infect(grid.get_cell(Vector2i.ZERO))
	disease.beta = 0.0
	disease.gamma = 0.0
	for algorithm: int in [0, 1, 2, 0]:
		engine.algorithm_override = algorithm
		check(engine.process_turn(grid, database), "Compatible runtime switch")
		check(grid.get_cell(Vector2i.ZERO).infected_fraction == 1.0, "Switch preserves fractions")
	check(grid.get_cell(Vector2i.ZERO).sir_state == SimulationEnums.SIRState.I, "CA syncs categorical state")

	# Disease default and explicit override are both honored.
	engine.algorithm_override = -1
	disease.default_algorithm = SimulationEnums.SimulationAlgorithm.SPATIAL_SEIR
	disease.beta = 1.0
	check(engine.process_turn(grid, database), "Disease default used")
	check(grid.get_cell(Vector2i(1, 0)).exposed_fraction > 0.0, "Default SEIR exposes")
	disease.default_algorithm = SimulationEnums.SimulationAlgorithm.SPATIAL_SIR

	# Seed reproducibility over many draws; catalog order must not affect draws.
	var ca_a: SimulationController = SimulationController.new()
	var ca_b: SimulationController = SimulationController.new()
	ca_a.algorithm_override = 2
	ca_b.algorithm_override = 2
	ca_a.rng.seed = 417
	ca_b.rng.seed = 417
	left = _grid(12)
	right = _grid(12)
	_infect(left.get_cell(Vector2i(5, 0)))
	_infect(right.get_cell(Vector2i(5, 0)))
	disease.gamma = 0.25
	disease.xi = 0.2
	disease.mortality_probability = 0.35
	var other: DiseaseData = DiseaseData.new()
	other.disease_id = SimulationEnums.DiseaseId.RICE_BLAST
	other.target_crop = SimulationEnums.CropType.RICE
	other.display_name = "Unrelated rice disease"
	database.diseases.append(other)
	var reversed_catalog: DiseaseDatabase = DiseaseDatabase.new()
	reversed_catalog.diseases.assign([other, disease])
	for tick: int in range(40):
		check(ca_a.process_turn(left, database) and ca_b.process_turn(right, reversed_catalog), "Seeded CA turn")
		for x: int in range(12):
			var a: FieldCellState = left.get_cell(Vector2i(x, 0))
			var b: FieldCellState = right.get_cell(Vector2i(x, 0))
			check(CompartmentMath.fractions(a) == CompartmentMath.fractions(b), "Seed and catalog-order reproducibility")
			check(CompartmentMath.one_hot_index(a) >= 0, "CA stays one-hot")
		check(ca_a.rng.state == ca_b.rng.state, "Identical draw sequence")
	_check_fractions(left)

	# Endpoint probabilities, separate mortality decision, absorbing death and waning.
	database.diseases.resize(1)
	disease.gamma = 1.0e30
	disease.xi = 1.0e30
	disease.mortality_probability = 1.0
	grid = _grid(1)
	_infect(grid.get_cell(Vector2i.ZERO))
	check(ca_a.process_turn(grid, database), "Certain CA removal")
	check(grid.get_cell(Vector2i.ZERO).dead_fraction == 1.0, "Certain mortality")
	check(ca_a.process_turn(grid, database) and grid.get_cell(Vector2i.ZERO).dead_fraction == 1.0, "Dead is absorbing")
	disease.mortality_probability = 0.0
	grid = _grid(1)
	_infect(grid.get_cell(Vector2i.ZERO))
	check(ca_a.process_turn(grid, database), "CA recovery")
	check(grid.get_cell(Vector2i.ZERO).recovered_immune_fraction == 1.0, "No same-tick recovery and waning")
	check(ca_a.process_turn(grid, database) and grid.get_cell(Vector2i.ZERO).susceptible_fraction == 1.0, "CA immunity wanes next turn")

	# High-rate continuous runs conserve mass without negative compartments.
	for algorithm: int in [0, 1]:
		engine.algorithm_override = algorithm
		grid = _grid(7)
		_infect(grid.get_cell(Vector2i(3, 0)))
		disease.beta = 200.0
		disease.sigma = 80.0
		disease.gamma = 40.0
		disease.xi = 20.0
		disease.mortality_probability = 0.17
		for tick: int in range(100):
			check(engine.process_turn(grid, database), "High-rate turn")
			_check_fractions(grid)

	# Different diseases cannot both claim a healthy cell.
	grid = _grid(3)
	_infect(grid.get_cell(Vector2i.ZERO))
	var smut: DiseaseData = disease.copy()
	smut.disease_id = SimulationEnums.DiseaseId.SUGARCANE_SMUT
	smut.display_name = "Smut"
	database.diseases.append(smut)
	_infect(grid.get_cell(Vector2i(2, 0)))
	grid.get_cell(Vector2i(2, 0)).active_disease_id = smut.disease_id
	engine.algorithm_override = 0
	check(not engine.process_turn(grid, database), "Ambiguous exposure rejected")
	engine.active_disease_filter = int(disease.disease_id)
	check(engine.process_turn(grid, database), "Explicit disease filter resolves ambiguity")

	# Spatial decay and non-host geometry.
	database.diseases.resize(1)
	engine.active_disease_filter = -1
	disease.beta = 1.0
	disease.gamma = 0.0
	disease.distance_decay = 1.0
	grid = _grid(2)
	_infect(grid.get_cell(Vector2i.ZERO))
	check(engine.process_turn(grid, database), "Decay turn")
	check(is_equal_approx(grid.get_cell(Vector2i(1, 0)).infected_fraction, 1.0 - exp(-exp(-1.0))), "Exponential spatial kernel")
	grid = _grid(3)
	grid.get_cell(Vector2i(1, 0)).has_crop = false
	grid.get_cell(Vector2i(1, 0)).reset_crop_state()
	grid.get_cell(Vector2i(1, 0)).soil = null
	grid.get_cell(Vector2i(1, 0)).terrain_type = SimulationEnums.TerrainType.GRASS
	_infect(grid.get_cell(Vector2i.ZERO))
	disease.dispersal_radius = 2
	check(engine.process_turn(grid, database), "Grass geometry turn")
	check(grid.get_cell(Vector2i(2, 0)).infected_fraction > 0.0, "Grass does not block dispersal")
	check(grid.get_cell(Vector2i(1, 0)).infected_fraction == 0.0, "Grass is not a host")
	engine.time_step = NAN
	check(not engine.process_turn(grid, database), "Nonfinite timestep rejected")
	engine.time_step = 1.0
	engine.algorithm_override = 99
	check(not engine.process_turn(grid, database), "Invalid override rejected")
	var broken: BrokenModel = BrokenModel.new()
	grid = _grid(3)
	_infect(grid.get_cell(Vector2i.ZERO))
	var initial_rng: int = broken.rng.state
	check(not broken.process_turn(grid, database), "Invalid staged result rejects entire turn")
	check(grid.get_cell(Vector2i.ZERO).infected_fraction == 1.0 and grid.get_cell(Vector2i(1, 0)).susceptible_fraction == 1.0, "No staged cell commits after failure")
	check(broken.rng.state == initial_rng, "Failed evaluation restores RNG state")
	if failures == 0:
		print("EPIDEMIOLOGY_MODELS_PASS")
	quit(0 if failures == 0 else 1)


func _grid(width: int) -> FieldGridState:
	var grid: FieldGridState = FieldGridState.new()
	grid.initialize(width, 1, AbioticState.new())
	for x: int in range(width):
		var cell: FieldCellState = grid.get_cell(Vector2i(x, 0))
		cell.terrain_type = SimulationEnums.TerrainType.DRY_SOIL
		cell.soil = SoilState.new()
		cell.has_crop = true
		cell.reset_crop_state()
	return grid


func _database() -> DiseaseDatabase:
	var database: DiseaseDatabase = DiseaseDatabase.new()
	var disease: DiseaseData = DiseaseData.new()
	disease.display_name = "Test RSSI"
	disease.neighborhood_type = SimulationEnums.NeighborhoodType.VON_NEUMANN_4
	database.diseases.append(disease)
	return database


func _infect(cell: FieldCellState) -> void:
	cell.has_active_disease = true
	cell.active_disease_id = SimulationEnums.DiseaseId.RSSI
	CompartmentMath.set_one_hot(cell, 2)


func _check_fractions(grid: FieldGridState) -> void:
	for x: int in range(grid.width):
		var cell: FieldCellState = grid.get_cell(Vector2i(x, 0))
		var total: float = 0.0
		for value: float in CompartmentMath.fractions(cell):
			check(is_finite(value) and value >= 0.0 and value <= 1.0, "Bounded finite fractions")
			total += value
		check(absf(total - 1.0) < 1.0e-10, "Mass conservation")
		check(cell.validate().is_empty(), "Valid cell")


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)
