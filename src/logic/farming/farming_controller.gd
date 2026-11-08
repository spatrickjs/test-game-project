class_name FarmingController
extends Node
## Owns mutable field state. Presentation receives detached snapshots only.

signal field_initialized
signal cell_changed(coordinates: Vector2i)
signal planting_rejected(coordinates: Vector2i, reason: String)
signal action_queue_changed
signal action_finished(action_id: int, success: bool, reason: String)
signal queued_harvest_completed(result: HarvestResult)

@export var crop_database: CropDatabase
@export var terrain_database: TerrainDatabase
@export var initial_soil: SoilState
@export var initial_abiotic: AbioticState
@export var field_size: Vector2i = Vector2i(9, 6)
@export var terrain_bands: Array[SimulationEnums.TerrainType] = [
	SimulationEnums.TerrainType.DRY_SOIL,
	SimulationEnums.TerrainType.PADDY_MUD,
	SimulationEnums.TerrainType.GRASS,
]

var last_error: String = ""
var _grid: FieldGridState = null
var last_turn_introduction: DiseaseActivationRequest
var _actions: Array[FieldAction] = []
var _next_action_id: int = 1
var _revisions: Dictionary[Vector2i, int] = {}


func is_initialized() -> bool:
	return _grid != null


func initialize_field() -> bool:
	last_error = ""
	if crop_database == null or terrain_database == null:
		return _fail("Assign both crop_database and terrain_database.")
	if initial_soil == null or initial_abiotic == null:
		return _fail("Assign initial_soil and initial_abiotic.")
	if field_size.x < 1 or field_size.y < 1 or terrain_bands.is_empty():
		return _fail("Field dimensions must be positive and terrain_bands nonempty.")
	var errors: PackedStringArray = crop_database.validate()
	errors.append_array(terrain_database.validate())
	errors.append_array(initial_soil.validate())
	errors.append_array(initial_abiotic.validate())
	if not errors.is_empty():
		return _fail("\n".join(errors))
	for terrain_type: SimulationEnums.TerrainType in terrain_bands:
		if not terrain_database.has_terrain(terrain_type):
			return _fail("A terrain band has no registered terrain definition.")
	var candidate: FieldGridState = FieldGridState.new()
	if not candidate.initialize(field_size.x, field_size.y, initial_abiotic):
		return _fail("Could not initialize the field grid.")
	for y: int in range(field_size.y):
		for x: int in range(field_size.x):
			var band: int = mini(
				floori(float(x) * float(terrain_bands.size()) / float(field_size.x)),
				terrain_bands.size() - 1
			)
			var cell: FieldCellState = candidate.get_cell(Vector2i(x, y))
			cell.terrain_type = terrain_bands[band]
			var terrain: TerrainData = terrain_database.get_terrain(cell.terrain_type)
			if terrain.is_plantable:
				cell.soil = initial_soil.copy()
	errors = FieldGridQueries.validate_terrain_assignments(candidate, crop_database, terrain_database)
	if not errors.is_empty():
		return _fail("\n".join(errors))
	_grid = candidate
	_actions.clear()
	last_turn_introduction = null
	_revisions.clear()
	action_queue_changed.emit()
	field_initialized.emit()
	return true


func try_plant(coordinates: Vector2i, crop_type: SimulationEnums.CropType) -> bool:
	var reason: String = _planting_error(coordinates, crop_type)
	if not reason.is_empty():
		last_error = reason
		planting_rejected.emit(coordinates, reason)
		return false
	var cell: FieldCellState = _grid.get_cell(coordinates)
	cell.has_crop = true
	cell.crop_type = crop_type
	cell.reset_crop_state()
	last_error = ""
	_emit_cell_changed(coordinates)
	return true


## One discrete healthy-growth step. Validate before mutation to avoid partial turns.
## Batch rendering is triggered by TurnController after completion.
func advance_growth() -> bool:
	if has_pending_actions():
		return _fail("Wait for the farmer to finish queued actions before advancing time.")
	if _grid == null:
		return _fail("Initialize the field before advancing turns.")
	var candidate: FieldGridState = _grid.copy()
	var reason: String = _stage_growth(candidate)
	if not reason.is_empty():
		return _fail(reason)
	_grid = candidate
	last_error = ""
	return true


func _stage_growth(candidate: FieldGridState) -> String:
	var errors: PackedStringArray = FieldGridQueries.validate_terrain_assignments(candidate, crop_database, terrain_database)
	if not errors.is_empty():
		return "\n".join(errors)
	for y: int in range(candidate.height):
		for x: int in range(candidate.width):
			var cell: FieldCellState = candidate.get_cell(Vector2i(x, y))
			if not cell.has_crop:
				continue
			var crop: CropData = crop_database.get_crop(cell.crop_type)
			var result: CropGrowthModel.Result = CropGrowthModel.evaluate(cell, crop)
			if not result.errors.is_empty():
				return "\n".join(result.errors)
			cell.growth_elapsed_ticks = result.growth_elapsed_ticks
			cell.growth_remainder = result.growth_remainder
			cell.vitality = result.vitality
			cell.yield_quality_loss = result.yield_quality_loss
	return "\n".join(candidate.validate())


## State clearing only, without harvesting/reward mechanics.
func clear_crop(coordinates: Vector2i) -> bool:
	if _grid == null:
		return _fail("Initialize the field before clearing crops.")
	var cell: FieldCellState = _grid.get_cell(coordinates)
	if cell == null:
		return _fail("Choose a tile inside the field.")
	cell.has_crop = false
	cell.reset_crop_state()
	last_error = ""
	_emit_cell_changed(coordinates)
	return true


## Player-facing roguing rejects empty targets; clear_crop remains idempotent.
func remove_crop(coordinates: Vector2i) -> bool:
	if _grid == null:
		return _fail("Initialize the field before removing crops.")
	var cell: FieldCellState = _grid.get_cell(coordinates)
	if cell == null or not cell.has_crop:
		return _fail("Choose a tile containing a crop to remove.")
	return clear_crop(coordinates)


## Atomic payload move. Soil, terrain and coordinates belong to the location.
## Actions do not advance the clock or alter any crop/disease fractions.
func transfer_crop(source: Vector2i, destination: Vector2i) -> bool:
	if _grid == null:
		return _fail("Initialize the field before moving crops.")
	if source == destination:
		return _fail("Choose a different destination tile.")
	var origin: FieldCellState = _grid.get_cell(source)
	if origin == null or not origin.has_crop:
		return _fail("Choose a source tile containing a crop.")
	var reason: String = _planting_error(destination, origin.crop_type)
	if not reason.is_empty():
		return _fail(reason)
	var candidate: FieldGridState = _grid.copy()
	var target: FieldCellState = candidate.get_cell(destination)
	var moved: FieldCellState = origin.copy()
	moved.coordinates = destination
	moved.terrain_type = target.terrain_type
	moved.soil = target.soil
	if not candidate.set_cell(moved):
		return _fail("The source crop state is invalid; transfer was cancelled.")
	var cleared: FieldCellState = candidate.get_cell(source)
	cleared.has_crop = false
	cleared.reset_crop_state()
	var errors: PackedStringArray = FieldGridQueries.validate_terrain_assignments(candidate, crop_database, terrain_database)
	if not errors.is_empty():
		return _fail("\n".join(errors))
	_grid = candidate
	last_error = ""
	# Both cells are already committed before any observer receives a signal.
	_emit_cell_changed(source)
	_emit_cell_changed(destination)
	return true


## Logic-only bridge; no authoritative grid escapes to Presentation.
func process_simulation(simulation: SimulationController, diseases: DiseaseDatabase) -> bool:
	simulation.crop_database = crop_database
	return simulation.process_turn(_grid, diseases)


## Transaction boundary: no growth or epidemic state survives a failed turn.
func advance_simulated_turn(simulation: SimulationController, diseases: DiseaseDatabase, weather: WeatherManager = null, turn_index: int = 0, activation: DiseaseActivationController = null, allow_introduction: bool = true) -> bool:
	last_turn_introduction = null
	if has_pending_actions():
		return _fail("Wait for the farmer to finish queued actions before advancing time.")
	if simulation == null:
		return _fail("Assign a simulation controller.")
	simulation.crop_database = crop_database
	var errors: PackedStringArray = simulation.validate_turn(_grid, diseases)
	if not errors.is_empty():
		return _fail("\n".join(errors))
	var before: FieldGridState = _grid
	var candidate: FieldGridState = _grid.copy()
	var rng_before: int = simulation.rng.state
	var caps_before: Vector3i = Vector3i(simulation.weather_cap_count, simulation.beta_cap_count, simulation.hazard_cap_count)
	var reason: String = ""
	if weather != null and not weather.apply_to_grid(candidate, turn_index):
		reason = weather.last_error
	if reason.is_empty():
		reason = _stage_growth(candidate)
	if reason.is_empty() and not simulation.process_turn(candidate, diseases):
		reason = simulation.last_error
	var proposal: DiseaseActivationController.Result
	if reason.is_empty() and activation != null:
		proposal = activation.evaluate(candidate.copy(), diseases, turn_index + 1, simulation.active_disease_filter, allow_introduction)
		reason = "\n".join(proposal.errors)
		if reason.is_empty() and proposal.request != null:
			reason = _stage_infection(candidate, proposal.request.coordinates, proposal.request.disease_id, diseases, simulation)
	if reason.is_empty():
		reason = "\n".join(simulation.validate_turn(candidate, diseases))
	if not reason.is_empty():
		simulation.rng.state = rng_before
		simulation.weather_cap_count = caps_before.x
		simulation.beta_cap_count = caps_before.y
		simulation.hazard_cap_count = caps_before.z
		return _fail(reason)
	_grid = candidate
	if proposal != null:
		activation.commit_state(proposal.next_state)
		last_turn_introduction = proposal.request
		if proposal.request != null:
			var coordinates: Vector2i = proposal.request.coordinates
			_revisions[coordinates] = _revisions.get(coordinates, 0) + 1
	last_error = ""
	if weather != null:
		weather.report_committed_moisture(before, _grid, turn_index + 1)
	return true


## Debug action; never changes growth, soil, or turn count.
func seed_infection(coordinates: Vector2i, disease_id: SimulationEnums.DiseaseId, diseases: DiseaseDatabase, simulation: SimulationController) -> bool:
	if _grid == null or diseases == null or simulation == null:
		return _fail("Initialize the field and assign simulation/catalog first.")
	var candidate: FieldGridState = _grid.copy()
	var reason: String = _stage_infection(candidate, coordinates, disease_id, diseases, simulation)
	if not reason.is_empty():
		return _fail(reason)
	_grid = candidate
	last_error = ""
	_emit_cell_changed(coordinates)
	return true


## Shared by manual debug seeding and automatic staged game introductions.
func _stage_infection(candidate: FieldGridState, coordinates: Vector2i, disease_id: SimulationEnums.DiseaseId, diseases: DiseaseDatabase, simulation: SimulationController) -> String:
	var disease: DiseaseData = diseases.get_disease(disease_id)
	var seeded: FieldCellState = candidate.get_cell(coordinates)
	if not DiseaseActivationController.is_eligible(seeded, disease):
		return "Choose a clean, fully susceptible compatible crop with a registered disease."
	seeded.has_active_disease = true
	seeded.active_disease_id = disease_id
	seeded.sir_state = SimulationEnums.SIRState.I
	seeded.removed_outcome = SimulationEnums.RemovedOutcome.NONE
	var algorithm: int = disease.default_algorithm if simulation.algorithm_override == -1 else simulation.algorithm_override
	seeded.infected_fraction = 1.0 if algorithm == SimulationEnums.SimulationAlgorithm.STOCHASTIC_CA_SIR else 0.2
	seeded.susceptible_fraction = 1.0 - seeded.infected_fraction
	simulation.crop_database = crop_database
	return "\n".join(simulation.validate_turn(candidate, diseases))


func get_grid_snapshot() -> FieldGridState:
	if _grid == null:
		return null
	return _grid.copy()


func _planting_error(coordinates: Vector2i, crop_type: SimulationEnums.CropType) -> String:
	if _grid == null:
		return "The field is not initialized."
	if crop_database == null or terrain_database == null:
		return "Catalog configuration is missing."
	var cell: FieldCellState = _grid.get_cell(coordinates)
	if cell == null:
		return "Choose a tile inside the field."
	if cell.has_crop:
		return "This tile already contains a crop."
	var crop: CropData = crop_database.get_crop(crop_type)
	if crop == null:
		return "The selected crop is not registered."
	var terrain: TerrainData = terrain_database.get_terrain(cell.terrain_type)
	if terrain == null:
		return "This terrain is not registered."
	if not terrain.is_plantable:
		return "%s cannot be planted." % terrain.display_name
	if not terrain.allowed_crops.has(crop_type):
		return "%s cannot grow on %s." % [crop.display_name, terrain.display_name]
	if not FieldGridQueries.can_plant(_grid, coordinates, crop_type, crop_database, terrain_database):
		return "The tile or crop configuration is invalid; check soil and catalog values."
	return ""


func _fail(message: String) -> bool:
	last_error = message
	return false


func _emit_cell_changed(coordinates: Vector2i) -> void:
	_revisions[coordinates] = _revisions.get(coordinates, 0) + 1
	cell_changed.emit(coordinates)


func has_pending_actions() -> bool:
	return not _actions.is_empty()


func get_current_action() -> FieldAction:
	return null if _actions.is_empty() else _actions[0].copy()


func get_queued_coordinates() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for action: FieldAction in _actions:
		result.append(action.target)
		if action.kind == SimulationEnums.FieldActionKind.MOVE_CROP:
			result.append(action.source)
	return result


## Shared read-only validation for indicators, enqueue and arrival.
func action_error(action: FieldAction, check_reservations: bool = true) -> String:
	if action == null or _grid == null:
		return "Initialize the field before selecting an action."
	var cell: FieldCellState = _grid.get_cell(action.target)
	if cell == null:
		return "Choose a tile inside the field."
	if check_reservations:
		var reserved: Array[Vector2i] = get_queued_coordinates()
		if reserved.has(action.target) or (action.kind == SimulationEnums.FieldActionKind.MOVE_CROP and reserved.has(action.source)):
			return "This plot already has a queued action."
	match action.kind:
		SimulationEnums.FieldActionKind.REMOVE_CROP:
			return "Choose a crop to remove." if not cell.has_crop else ""
		SimulationEnums.FieldActionKind.DIG_GRASS:
			if cell.has_crop or cell.terrain_type != SimulationEnums.TerrainType.GRASS:
				return "Shovel conversion requires empty grass."
			if initial_soil == null or not initial_soil.validate().is_empty():
				return "Configure valid initial soil before digging."
			return _conversion_catalog_error(SimulationEnums.TerrainType.DRY_SOIL)
		SimulationEnums.FieldActionKind.MAKE_PADDY:
			if cell.has_crop or cell.terrain_type != SimulationEnums.TerrainType.DRY_SOIL:
				return "Water Bucket requires empty dry soil. Dig grass first."
			return _conversion_catalog_error(SimulationEnums.TerrainType.PADDY_MUD)
		SimulationEnums.FieldActionKind.PLANT:
			return _planting_error(action.target, action.crop_type)
		SimulationEnums.FieldActionKind.MOVE_CROP:
			var origin: FieldCellState = _grid.get_cell(action.source)
			if origin == null or not origin.has_crop or action.source == action.target:
				return "Choose a crop and a different compatible empty plot."
			return _planting_error(action.target, origin.crop_type)
		SimulationEnums.FieldActionKind.HARVEST:
			return "Choose a mature crop." if not cell.is_mature(crop_database.get_crop(cell.crop_type)) else ""
		SimulationEnums.FieldActionKind.WATER_SOIL, SimulationEnums.FieldActionKind.FERTILIZE:
			if cell.soil == null:
				return "Choose a tile with soil."
			var amount: Vector3 = action.additions
			if not amount.is_finite() or amount.x < 0.0 or amount.y < 0.0 or amount.z < 0.0 or amount.x > 1.0 or amount.y > 1.0 or amount.z > 1.0:
				return "Soil additions must be finite and in [0, 1]."
			return ""
	return "Unknown action."


func _conversion_catalog_error(terrain_type: SimulationEnums.TerrainType) -> String:
	var terrain: TerrainData = terrain_database.get_terrain(terrain_type) if terrain_database != null else null
	return "Conversion requires a valid plantable terrain definition." if terrain == null or not terrain.is_plantable or not terrain.validate().is_empty() else ""


## Enqueue a copied intent. Reserving coordinates never changes field state.
func enqueue_action(request: FieldAction) -> bool:
	var reason: String = action_error(request)
	if not reason.is_empty():
		return _fail(reason)
	var action: FieldAction = request.copy()
	action.id = _next_action_id
	_next_action_id += 1
	action.source_visited = false
	action.target_revision = _revisions.get(action.target, 0)
	action.source_revision = _revisions.get(action.source, 0)
	_actions.append(action)
	last_error = ""
	action_queue_changed.emit()
	return true


## Presentation reports only a completed stop, never edits a cell.
## Move pickup is a visit, not a destructive removal: commit both ends at delivery.
func arrive_at_action(action_id: int, stop: Vector2i) -> bool:
	if _actions.is_empty() or _actions[0].id != action_id or _actions[0].stop_coordinates() != stop:
		return _fail("Ignored an outdated arrival.")
	var action: FieldAction = _actions[0]
	var reason: String = action_error(action, false)
	if action.target_revision != _revisions.get(action.target, 0) or (action.kind == SimulationEnums.FieldActionKind.MOVE_CROP and action.source_revision != _revisions.get(action.source, 0)):
		reason = "The plot changed while the farmer was walking; action cancelled."
	if not reason.is_empty():
		_actions.pop_front()
		last_error = reason
		action_finished.emit(action.id, false, reason)
		action_queue_changed.emit()
		return false
	if action.kind == SimulationEnums.FieldActionKind.MOVE_CROP and not action.source_visited:
		action.source_visited = true
		action_queue_changed.emit()
		return true
	var success: bool = false
	var harvest: HarvestResult = null
	match action.kind:
		SimulationEnums.FieldActionKind.REMOVE_CROP:
			success = remove_crop(action.target)
		SimulationEnums.FieldActionKind.DIG_GRASS, SimulationEnums.FieldActionKind.MAKE_PADDY:
			success = _convert_terrain(action)
		SimulationEnums.FieldActionKind.PLANT:
			success = try_plant(action.target, action.crop_type)
		SimulationEnums.FieldActionKind.MOVE_CROP:
			success = transfer_crop(action.source, action.target)
		SimulationEnums.FieldActionKind.HARVEST:
			harvest = harvest_crop(action.target)
			success = harvest.success
		SimulationEnums.FieldActionKind.WATER_SOIL, SimulationEnums.FieldActionKind.FERTILIZE:
			success = apply_soil_additions(action.target, action.additions)
	_actions.pop_front()
	action_finished.emit(action.id, success, last_error)
	if harvest != null:
		queued_harvest_completed.emit(harvest)
	action_queue_changed.emit()
	return success


func cancel_actions() -> void:
	_actions.clear()
	action_queue_changed.emit()


func _convert_terrain(action: FieldAction) -> bool:
	var candidate: FieldGridState = _grid.copy()
	var cell: FieldCellState = candidate.get_cell(action.target)
	if action.kind == SimulationEnums.FieldActionKind.DIG_GRASS:
		cell.terrain_type = SimulationEnums.TerrainType.DRY_SOIL
		cell.soil = initial_soil.copy()
	else:
		cell.terrain_type = SimulationEnums.TerrainType.PADDY_MUD
	var errors: PackedStringArray = FieldGridQueries.validate_terrain_assignments(candidate, crop_database, terrain_database)
	if not errors.is_empty():
		return _fail("\n".join(errors))
	_grid = candidate
	last_error = ""
	_emit_cell_changed(action.target)
	return true


## Mature-only collection. Commit the clearing before observers receive a signal.
func harvest_crop(coordinates: Vector2i) -> HarvestResult:
	var result: HarvestResult = HarvestResult.new()
	result.coordinates = coordinates
	if _grid == null or crop_database == null or terrain_database == null:
		result.reason = "Initialize the field before harvesting."
	else:
		var cell: FieldCellState = _grid.get_cell(coordinates)
		if cell == null or not cell.has_crop:
			result.reason = "Choose a crop to harvest."
		else:
			var crop: CropData = crop_database.get_crop(cell.crop_type)
			if crop == null or not cell.is_mature(crop):
				result.reason = "This crop is not mature yet."
			else:
				var errors: PackedStringArray = FieldGridQueries.validate_terrain_assignments(_grid, crop_database, terrain_database)
				if not errors.is_empty():
					result.reason = "\n".join(errors)
				else:
					result.crop_type = cell.crop_type
					result.quality_multiplier = 1.0 - cell.yield_quality_loss
					var scoring: ScoringModel.Result = ScoringModel.evaluate(result, crop)
					result.base_score = scoring.base_score
					result.score = scoring.score
					var candidate: FieldGridState = _grid.copy()
					var cleared: FieldCellState = candidate.get_cell(coordinates)
					cleared.has_crop = false
					cleared.reset_crop_state()
					_grid = candidate
					result.success = true
	last_error = result.reason
	if result.success:
		_emit_cell_changed(coordinates)
	return result


## Atomic local soil edit. Vector components are moisture, nitrogen, potassium.
func apply_soil_additions(coordinates: Vector2i, additions: Vector3) -> bool:
	if _grid == null:
		return _fail("Initialize the field before using soil tools.")
	if not additions.is_finite() or additions.x < 0.0 or additions.y < 0.0 or additions.z < 0.0 or additions.x > 1.0 or additions.y > 1.0 or additions.z > 1.0:
		return _fail("Soil additions must be finite and in [0, 1].")
	var errors: PackedStringArray = FieldGridQueries.validate_terrain_assignments(_grid, crop_database, terrain_database)
	if not errors.is_empty():
		return _fail("\n".join(errors))
	var cell: FieldCellState = _grid.get_cell(coordinates)
	if cell == null or cell.soil == null:
		return _fail("Choose a tile with soil.")
	var candidate: FieldGridState = _grid.copy()
	var soil: SoilState = candidate.get_cell(coordinates).soil
	soil.moisture = minf(1.0, soil.moisture + additions.x)
	soil.nitrogen = minf(1.0, soil.nitrogen + additions.y)
	soil.potassium = minf(1.0, soil.potassium + additions.z)
	if soil.moisture == cell.soil.moisture and soil.nitrogen == cell.soil.nitrogen and soil.potassium == cell.soil.potassium:
		last_error = ""
		return true
	_grid = candidate
	last_error = ""
	_emit_cell_changed(coordinates)
	return true
