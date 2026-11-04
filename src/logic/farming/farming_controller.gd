class_name FarmingController
extends Node
## Owns mutable field state. Presentation receives detached snapshots only.

signal field_initialized
signal cell_changed(coordinates: Vector2i)
signal planting_rejected(coordinates: Vector2i, reason: String)

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
	cell_changed.emit(coordinates)
	return true


## One discrete healthy-growth step. Validate before mutation to avoid partial turns.
## Batch rendering is triggered by TurnController after completion.
func advance_growth() -> bool:
	if _grid == null:
		return _fail("Initialize the field before advancing turns.")
	var errors: PackedStringArray = FieldGridQueries.validate_terrain_assignments(
		_grid, crop_database, terrain_database
	)
	if not errors.is_empty():
		return _fail("\n".join(errors))
	for y: int in range(_grid.height):
		for x: int in range(_grid.width):
			var cell: FieldCellState = _grid.get_cell(Vector2i(x, y))
			if not cell.has_crop:
				continue
			var crop: CropData = crop_database.get_crop(cell.crop_type)
			if cell.growth_elapsed_ticks < crop.growth_ticks:
				cell.growth_elapsed_ticks += 1
	last_error = ""
	return true


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
	cell_changed.emit(coordinates)
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
	cell_changed.emit(source)
	cell_changed.emit(destination)
	return true


## Logic-only bridge; no authoritative grid escapes to Presentation.
func process_simulation(simulation: SimulationController, diseases: DiseaseDatabase) -> bool:
	simulation.crop_database = crop_database
	return simulation.process_turn(_grid, diseases)


## Transaction boundary: no growth or epidemic state survives a failed turn.
func advance_simulated_turn(simulation: SimulationController, diseases: DiseaseDatabase) -> bool:
	simulation.crop_database = crop_database
	var errors: PackedStringArray = simulation.validate_turn(_grid, diseases)
	if not errors.is_empty():
		return _fail("\n".join(errors))
	var before: FieldGridState = _grid.copy()
	if not advance_growth():
		return false
	if not process_simulation(simulation, diseases):
		_grid = before
		return _fail(simulation.last_error)
	return true


## Debug action; never changes growth, soil, or turn count.
func seed_infection(coordinates: Vector2i, disease_id: SimulationEnums.DiseaseId, diseases: DiseaseDatabase, simulation: SimulationController) -> bool:
	if _grid == null or diseases == null or simulation == null:
		return _fail("Initialize the field and assign simulation/catalog first.")
	var disease: DiseaseData = diseases.get_disease(disease_id)
	var cell: FieldCellState = _grid.get_cell(coordinates)
	if disease == null or cell == null or not cell.has_crop or cell.soil == null:
		return _fail("Select an occupied tile with a registered disease.")
	if disease.target_crop != cell.crop_type:
		return _fail("This disease cannot infect the selected crop.")
	if not cell.validate().is_empty():
		return _fail("The selected tile has invalid crop state.")
	if cell.has_active_disease or cell.susceptible_fraction != 1.0 or cell.exposed_fraction != 0.0 or cell.infected_fraction != 0.0 or cell.recovered_immune_fraction != 0.0 or cell.dead_fraction != 0.0:
		return _fail("Patient zero must be a clean, fully susceptible crop.")
	var candidate: FieldGridState = _grid.copy()
	var seeded: FieldCellState = candidate.get_cell(coordinates)
	seeded.has_active_disease = true
	seeded.active_disease_id = disease_id
	seeded.sir_state = SimulationEnums.SIRState.I
	seeded.removed_outcome = SimulationEnums.RemovedOutcome.NONE
	var algorithm: int = disease.default_algorithm if simulation.algorithm_override == -1 else simulation.algorithm_override
	seeded.infected_fraction = 1.0 if algorithm == SimulationEnums.SimulationAlgorithm.STOCHASTIC_CA_SIR else 0.2
	seeded.susceptible_fraction = 1.0 - seeded.infected_fraction
	simulation.crop_database = crop_database
	var errors: PackedStringArray = simulation.validate_turn(candidate, diseases)
	if not errors.is_empty():
		return _fail("\n".join(errors))
	_grid = candidate
	last_error = ""
	cell_changed.emit(coordinates)
	return true


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
