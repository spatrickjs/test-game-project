class_name FieldGridQueries
extends RefCounted
## Read-only gameplay queries. Terrain permissions come only from configuration.
## Geometric queries live independently in Simulation's GridNeighborhood.

## Connection mask bit constants. N=(0,-1), E=(1,0), S=(0,1), W=(-1,0).
const FENCE_BIT_N: int = 1
const FENCE_BIT_E: int = 2
const FENCE_BIT_S: int = 4
const FENCE_BIT_W: int = 8

## Cardinal offsets in (direction, bit) order.
const _FENCE_CARDINALS: Array = [
	[Vector2i(0, -1), 1],  # N
	[Vector2i(1,  0), 2],  # E
	[Vector2i(0,  1), 4],  # S
	[Vector2i(-1, 0), 8],  # W
]

## Returns a 4-bit connection mask for the fenced cell at coords.
## Bit N=1, E=2, S=4, W=8. OOB or non-fence neighbors contribute 0.
## Returns 0 when grid is null, coords are OOB, or the cell has no fence.
static func fence_connections(grid: FieldGridState, coords: Vector2i) -> int:
	if grid == null:
		return 0
	var cell: FieldCellState = grid.get_cell(coords)
	if cell == null or not cell.has_fence:
		return 0
	var mask: int = 0
	for pair: Array in _FENCE_CARDINALS:
		var offset: Vector2i = pair[0] as Vector2i
		var bit: int = pair[1] as int
		var neighbor: FieldCellState = grid.get_cell(coords + offset)
		if neighbor != null and neighbor.has_fence:
			mask |= bit
	return mask


## Fence shape identifiers. Used only by rendering; never persisted.
enum FenceShape { POST = 0, END = 1, STRAIGHT = 2, CORNER = 3, T = 4, CROSS = 5 }

## Classifies a connection mask into a FenceShape.
static func fence_shape(mask: int) -> FenceShape:
	var count: int = 0
	var m: int = mask & 0xF
	for bit: int in [1, 2, 4, 8]:
		if m & bit:
			count += 1
	match count:
		0: return FenceShape.POST
		1: return FenceShape.END
		3: return FenceShape.T
		4: return FenceShape.CROSS
		2:
			# Two opposite bits → straight; two adjacent → corner.
			var opposites: Array = [[1, 4], [2, 8]]  # [N,S], [E,W]
			for pair: Array in opposites:
				if m & pair[0] and m & pair[1]:
					return FenceShape.STRAIGHT
			return FenceShape.CORNER
	return FenceShape.POST


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
