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
	cell.growth_elapsed_ticks = 0
	cell.sir_state = SimulationEnums.SIRState.S
	cell.removed_outcome = SimulationEnums.RemovedOutcome.NONE
	cell.has_active_disease = false
	cell.active_disease_id = SimulationEnums.DiseaseId.RSSI
	cell.susceptible_fraction = 1.0
	cell.exposed_fraction = 0.0
	cell.infected_fraction = 0.0
	cell.recovered_immune_fraction = 0.0
	cell.dead_fraction = 0.0
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
