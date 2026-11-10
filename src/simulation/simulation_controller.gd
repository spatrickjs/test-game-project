class_name SimulationController
extends RefCounted
## Fractional and categorical updates read a detached start-of-turn snapshot.
## Environmental responses are evaluated once, then shared by all three models.

var algorithm_override: int = -1
var active_disease_filter: int = -1
var time_step: float = 1.0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var last_error: String = ""
var crop_database: CropDatabase = null
## Diagnostics for the last successful turn (failed turns discard counts).
var weather_cap_count: int = 0
var beta_cap_count: int = 0
var hazard_cap_count: int = 0
## Print a line each time a cell newly acquires an active disease via spread.
var debug_infections: bool = true

var _sir: SpatialSIRModel = SpatialSIRModel.new()
var _seir: SpatialSEIRModel = SpatialSEIRModel.new()
var _ca: StochasticCASIRModel = StochasticCASIRModel.new()


func validate_turn(grid: FieldGridState, database: DiseaseDatabase) -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if grid == null or database == null:
		errors.append("Grid and disease catalog are required.")
		return errors
	if algorithm_override != -1 and not SimulationEnums.SimulationAlgorithm.values().has(algorithm_override):
		errors.append("Invalid algorithm_override.")
	if active_disease_filter != -1 and database.get_disease(active_disease_filter as SimulationEnums.DiseaseId) == null:
		errors.append("Disease filter is not registered.")
	if not is_finite(time_step) or time_step <= 0.0:
		errors.append("time_step must be finite and positive.")
	if rng == null:
		errors.append("Assign a RandomNumberGenerator.")
	errors.append_array(grid.validate())
	errors.append_array(database.validate())
	if crop_database != null:
		errors.append_array(crop_database.validate())
	for disease: DiseaseData in database.diseases:
		if disease != null and TransmissionModifiers.needs_crop(disease.transmission_modifier_profile):
			if crop_database == null or crop_database.get_crop(disease.target_crop) == null:
				errors.append("Enabled nutrient modifiers require a registered crop definition.")
	if not errors.is_empty() or database.diseases.is_empty():
		return errors
	for y: int in range(grid.height):
		for x: int in range(grid.width):
			var cell: FieldCellState = grid.get_cell(Vector2i(x, y))
			if not cell.has_crop:
				continue
			if cell.soil == null or cell.terrain_type == SimulationEnums.TerrainType.GRASS:
				errors.append("Occupied cell %s is not a valid host." % cell.coordinates)
				continue
			if not cell.has_active_disease and cell.susceptible_fraction != 1.0:
				errors.append("Cell %s has disease compartments but no disease identity." % cell.coordinates)
			if cell.has_active_disease:
				var registered: DiseaseData = database.get_disease(cell.active_disease_id)
				if registered == null or registered.target_crop != cell.crop_type:
					errors.append("Cell %s has an unregistered/incompatible active disease." % cell.coordinates)
					continue
			var exposed_to: int = 0
			for disease: DiseaseData in _candidates(cell, database):
				var algorithm: int = _algorithm(disease)
				if algorithm != SimulationEnums.SimulationAlgorithm.SPATIAL_SEIR and cell.exposed_fraction > 0.0:
					errors.append("Cell %s: SIR/CA cannot discard exposed fractions." % cell.coordinates)
				if algorithm == SimulationEnums.SimulationAlgorithm.STOCHASTIC_CA_SIR and CompartmentMath.one_hot_index(cell) < 0:
					errors.append("Cell %s: CA requires exact one-hot fractions." % cell.coordinates)
				if _transmission(cell, disease, _neighbors(grid, cell, disease), grid.abiotic_state).hazard > 0.0:
					exposed_to += 1
			if not cell.has_active_disease and exposed_to > 1:
				errors.append("Cell %s has ambiguous exposure; select active_disease_filter." % cell.coordinates)
	return errors


func process_turn(grid_state: FieldGridState, disease_database: DiseaseDatabase) -> bool:
	last_error = ""
	weather_cap_count = 0
	beta_cap_count = 0
	hazard_cap_count = 0
	var errors: PackedStringArray = validate_turn(grid_state, disease_database)
	if not errors.is_empty():
		last_error = "\n".join(errors)
		return false
	if disease_database.diseases.is_empty():
		return true
	var snapshot: FieldGridState = grid_state.copy()
	var staged: Array[FieldCellState] = []
	var rng_before: int = rng.state
	# Canonical coordinate and disease-ID order makes CA independent of storage order.
	for y: int in range(snapshot.height):
		for x: int in range(snapshot.width):
			var cell: FieldCellState = snapshot.get_cell(Vector2i(x, y))
			if not cell.has_crop:
				continue
			var candidates: Array[DiseaseData] = _candidates(cell, disease_database)
			for disease: DiseaseData in candidates:
				var neighbors: Array[FieldCellState] = _neighbors(snapshot, cell, disease)
				if not cell.has_active_disease and candidates.size() > 1:
					if _transmission(cell, disease, neighbors, snapshot.abiotic_state).hazard == 0.0:
						continue
				var next: FieldCellState = _evaluate_cell(cell, disease, neighbors, snapshot.abiotic_state)
				if next == null:
					last_error = "Model returned no state."
					weather_cap_count = 0
					beta_cap_count = 0
					hazard_cap_count = 0
					rng.state = rng_before
					return false
				if next.exposed_fraction > 0.0 or next.infected_fraction > 0.0 or next.recovered_immune_fraction > 0.0 or next.dead_fraction > 0.0:
					next.has_active_disease = true
					next.active_disease_id = disease.disease_id
				# Retain disease identity through recovery/waning to preserve immunity scope.
				errors = next.validate()
				if not errors.is_empty():
					last_error = "\n".join(errors)
					weather_cap_count = 0
					beta_cap_count = 0
					hazard_cap_count = 0
					rng.state = rng_before
					return false
				staged.append(next)
				break
	# No authoritative state has been changed before this commit.
	for next: FieldCellState in staged:
		var target: FieldCellState = grid_state.get_cell(next.coordinates)
		var was_infected: bool = target.has_active_disease
		target.susceptible_fraction = next.susceptible_fraction
		target.exposed_fraction = next.exposed_fraction
		target.infected_fraction = next.infected_fraction
		target.recovered_immune_fraction = next.recovered_immune_fraction
		target.dead_fraction = next.dead_fraction
		target.sir_state = next.sir_state
		target.removed_outcome = next.removed_outcome
		target.has_active_disease = next.has_active_disease
		target.active_disease_id = next.active_disease_id
		if debug_infections and not was_infected and next.has_active_disease:
			var disease: DiseaseData = disease_database.get_disease(next.active_disease_id)
			var disease_name: String = disease.display_name if disease != null else str(next.active_disease_id)
			print("Infection spread: %s infected cell %s (infected_fraction=%.2f)." % [disease_name, next.coordinates, next.infected_fraction])
	return true


func _evaluate_cell(cell: FieldCellState, disease: DiseaseData, neighbors: Array[FieldCellState], environment: AbioticState) -> FieldCellState:
	var response: TransmissionModifiers.Result = _transmission(cell, disease, neighbors, environment)
	weather_cap_count += int(response.weather_capped)
	beta_cap_count += int(response.beta_capped)
	hazard_cap_count += int(response.hazard_capped)
	match _algorithm(disease):
		SimulationEnums.SimulationAlgorithm.SPATIAL_SEIR:
			return _seir.evaluate(cell, disease, response.hazard, time_step)
		SimulationEnums.SimulationAlgorithm.STOCHASTIC_CA_SIR:
			return _ca.evaluate(cell, disease, response.hazard, time_step, rng)
	return _sir.evaluate(cell, disease, response.hazard, time_step)


func _transmission(cell: FieldCellState, disease: DiseaseData, neighbors: Array[FieldCellState], environment: AbioticState) -> TransmissionModifiers.Result:
	var crop: CropData = crop_database.get_crop(cell.crop_type) if crop_database != null else null
	return TransmissionModifiers.evaluate(disease, environment, cell.soil, crop, _pressure(cell, disease, neighbors))


func _algorithm(disease: DiseaseData) -> int:
	return disease.default_algorithm if algorithm_override == -1 else algorithm_override


func _candidates(cell: FieldCellState, database: DiseaseDatabase) -> Array[DiseaseData]:
	var result: Array[DiseaseData] = []
	for disease: DiseaseData in database.get_diseases_for_crop(cell.crop_type):
		if active_disease_filter != -1 and int(disease.disease_id) != active_disease_filter:
			continue
		if cell.has_active_disease and cell.active_disease_id != disease.disease_id:
			continue
		result.append(disease)
	result.sort_custom(func(a: DiseaseData, b: DiseaseData) -> bool: return a.disease_id < b.disease_id)
	return result


func _neighbors(grid: FieldGridState, cell: FieldCellState, disease: DiseaseData) -> Array[FieldCellState]:
	var result: Array[FieldCellState] = []
	for coordinates: Vector2i in GridNeighborhood.get_neighbor_coordinates(grid, cell.coordinates, disease.neighborhood_type, disease.dispersal_radius):
		result.append(grid.get_cell(coordinates))
	return result


func _pressure(cell: FieldCellState, disease: DiseaseData, neighbors: Array[FieldCellState]) -> float:
	var pressure: float = 0.0
	for neighbor: FieldCellState in neighbors:
		if not neighbor.has_crop or neighbor.soil == null or neighbor.terrain_type == SimulationEnums.TerrainType.GRASS:
			continue
		if neighbor.crop_type != disease.target_crop or not neighbor.has_active_disease or neighbor.active_disease_id != disease.disease_id:
			continue
		var infection: float = neighbor.infected_fraction
		if _algorithm(disease) == SimulationEnums.SimulationAlgorithm.STOCHASTIC_CA_SIR:
			# One-hot entry is validated; derive the category when switching from continuous.
			infection = 1.0 if CompartmentMath.one_hot_index(neighbor) == 2 else 0.0
		var distance: float = GridNeighborhood.get_distance_in_tiles(cell.coordinates, neighbor.coordinates)
		pressure += exp(-disease.distance_decay * distance) * infection
	return pressure
