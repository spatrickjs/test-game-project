class_name FieldGridQueries
extends RefCounted
## Read-only gameplay queries. Terrain permissions come only from configuration.
## Geometric queries live independently in Simulation's GridNeighborhood.


static func can_plant(
	grid: FieldGridState,
	coordinates: Vector2i,
	crop_type: SimulationEnums.CropType,
	crops: CropDatabase,
	terrains: TerrainDatabase
) -> bool:
	if grid == null or crops == null or terrains == null:
		return false
	var cell: FieldCellState = grid.get_cell(coordinates)
	if cell == null or cell.has_crop or cell.soil == null:
		return false
	var crop: CropData = crops.get_crop(crop_type)
	var terrain: TerrainData = terrains.get_terrain(cell.terrain_type)
	if crop == null or terrain == null:
		return false
	if not terrain.is_plantable or not terrain.allowed_crops.has(crop_type):
		return false
	if not crop.validate().is_empty() or not terrain.validate().is_empty():
		return false
	# Includes soil validation and rejects stale runtime state in empty cells.
	return cell.validate().is_empty()


## Combines structural/catalog validation with assignment-specific checks.
## Unplantable terrain has no soil or crop; plantable terrain requires soil.
## This expresses the initial grass/dry-soil/paddy behavior without terrain-ID
## branches and keeps future terrain permissions data-driven.
static func validate_terrain_assignments(
	grid: FieldGridState,
	crops: CropDatabase,
	terrains: TerrainDatabase
) -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if grid == null:
		errors.append("grid is required.")
	if crops == null:
		errors.append("crops catalog is required.")
	if terrains == null:
		errors.append("terrains catalog is required.")
	if grid == null or crops == null or terrains == null:
		return errors
	var grid_errors: PackedStringArray = grid.validate()
	for error: String in grid_errors:
		errors.append("grid: %s" % error)
	for error: String in crops.validate():
		errors.append("crops catalog: %s" % error)
	for error: String in terrains.validate():
		errors.append("terrains catalog: %s" % error)
	# Coordinate iteration is safe only for structurally valid storage.
	# Repair reported state errors before checking terrain assignments.
	if not grid_errors.is_empty():
		return errors
	for y: int in range(grid.height):
		for x: int in range(grid.width):
			var coordinates: Vector2i = Vector2i(x, y)
			var cell: FieldCellState = grid.get_cell(coordinates)
			var prefix: String = "cells[(%d, %d)]" % [x, y]
			if cell == null:
				errors.append("%s: cell is missing." % prefix)
				continue
			var terrain: TerrainData = terrains.get_terrain(cell.terrain_type)
			if terrain == null:
				errors.append("%s: terrain_type is not registered." % prefix)
				continue
			if terrain.is_plantable:
				if cell.soil == null:
					errors.append("%s: plantable terrain requires soil." % prefix)
			else:
				if cell.soil != null:
					errors.append("%s: unplantable terrain must have null soil." % prefix)
				if cell.has_crop:
					errors.append("%s: unplantable terrain cannot host a crop." % prefix)
			if cell.has_crop:
				if not crops.has_crop(cell.crop_type):
					errors.append("%s: crop_type is not registered." % prefix)
				if not terrain.allowed_crops.has(cell.crop_type):
					errors.append("%s: terrain does not permit this crop_type." % prefix)
			if cell.has_fence and cell.terrain_type != SimulationEnums.TerrainType.GRASS:
				errors.append("%s: fenced cell must be on grass terrain." % prefix)
	return errors
