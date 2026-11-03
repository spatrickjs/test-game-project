class_name FieldGridState
extends RefCounted
## Row-major runtime storage. Accessors return live cells for Logic/Simulation.
## Presentation must treat these references as read-only.
## Use initialize() to change dimensions; direct dimension edits invalidate storage.

var width: int = 0
var height: int = 0
var abiotic_state: AbioticState = null
var _cells: Array[FieldCellState] = []


## Builds distinct empty grass cells. Failure preserves the previous grid.
## Copies the supplied environment so separately initialized grids do not share it.
func initialize(grid_width: int, grid_height: int, environment: AbioticState) -> bool:
	if grid_width <= 0 or grid_height <= 0 or environment == null:
		return false
	if not environment.validate().is_empty():
		return false
	# Array sizes use signed 32-bit lengths. Bound before integer multiplication.
	if float(grid_width) * float(grid_height) > 2147483647.0:
		return false
	var new_cells: Array[FieldCellState] = []
	if new_cells.resize(grid_width * grid_height) != OK:
		return false
	for y: int in range(grid_height):
		for x: int in range(grid_width):
			var cell: FieldCellState = FieldCellState.new()
			cell.coordinates = Vector2i(x, y)
			new_cells[y * grid_width + x] = cell
	width = grid_width
	height = grid_height
	abiotic_state = environment.copy()
	_cells = new_cells
	return true


func is_in_bounds(coordinates: Vector2i) -> bool:
	return (
		coordinates.x >= 0 and coordinates.y >= 0
		and coordinates.x < width and coordinates.y < height
	)


func get_cell(coordinates: Vector2i) -> FieldCellState:
	if not is_in_bounds(coordinates):
		return null
	var index: int = coordinates.y * width + coordinates.x
	if index < 0 or index >= _cells.size():
		return null
	var cell: FieldCellState = _cells[index]
	if cell == null or cell.coordinates != coordinates:
		return null
	return cell


## Stores the supplied instance, not a copy. Rejects malformed or aliased cells.
## Catalog-dependent terrain rules are checked separately by FieldGridQueries.
func set_cell(cell: FieldCellState) -> bool:
	if cell == null or not is_in_bounds(cell.coordinates):
		return false
	if not cell.validate().is_empty():
		return false
	if _cells.size() != width * height:
		return false
	var target_index: int = cell.coordinates.y * width + cell.coordinates.x
	for index: int in range(_cells.size()):
		if index == target_index:
			continue
		var existing: FieldCellState = _cells[index]
		if existing == cell:
			return false
		if existing != null and cell.soil != null and existing.soil == cell.soil:
			return false
	_cells[target_index] = cell
	return true


func validate() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if width <= 0 or height <= 0:
		errors.append("width and height must be positive.")
	elif float(width) * float(height) != float(_cells.size()):
		errors.append("cell count must equal width * height.")
	if abiotic_state == null:
		errors.append("abiotic_state is required.")
	else:
		for error: String in abiotic_state.validate():
			errors.append("abiotic_state: %s" % error)
	var seen_cells: Dictionary[int, int] = {}
	var seen_soils: Dictionary[int, int] = {}
	for index: int in range(_cells.size()):
		var cell: FieldCellState = _cells[index]
		if cell == null:
			errors.append("cells[%d]: entry must not be null." % index)
			continue
		if width > 0:
			var expected: Vector2i = Vector2i(index % width, floori(float(index) / float(width)))
			if cell.coordinates != expected:
				errors.append("cells[%d]: coordinates do not match row-major position." % index)
		if not is_in_bounds(cell.coordinates):
			errors.append("cells[%d]: coordinates are outside the grid." % index)
		var cell_id: int = cell.get_instance_id()
		if seen_cells.has(cell_id):
			errors.append("cells[%d]: shares a cell instance with cells[%d]." % [index, seen_cells[cell_id]])
		else:
			seen_cells[cell_id] = index
		if cell.soil != null:
			var soil_id: int = cell.soil.get_instance_id()
			if seen_soils.has(soil_id):
				errors.append("cells[%d]: shares soil with cells[%d]." % [index, seen_soils[soil_id]])
			else:
				seen_soils[soil_id] = index
		for error: String in cell.validate():
			errors.append("cells[%d]: %s" % [index, error])
	return errors


## Copies nested runtime values, including null entries, without clamping.
func copy() -> FieldGridState:
	var result: FieldGridState = FieldGridState.new()
	result.width = width
	result.height = height
	if abiotic_state != null:
		result.abiotic_state = abiotic_state.copy()
	for cell: FieldCellState in _cells:
		if cell == null:
			result._cells.append(null)
		else:
			result._cells.append(cell.copy())
	return result
