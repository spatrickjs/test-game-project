class_name GridNeighborhood
extends RefCounted
## Pure geometry. No terrain, crop, disease, scene, or Game Logic dependencies.


## Deterministic row order; clips to edges and excludes the center.
## Grass remains part of geometry and does not obstruct dispersal.
static func get_neighbor_coordinates(
	grid: FieldGridState,
	center: Vector2i,
	neighborhood_type: SimulationEnums.NeighborhoodType,
	dispersal_radius: int
) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	if grid == null or not grid.is_in_bounds(center) or dispersal_radius < 1:
		return neighbors
	if not SimulationEnums.NeighborhoodType.values().has(neighborhood_type):
		return neighbors
	# Clip the radius before coordinate arithmetic; huge radii need not loop
	# over coordinates outside the field.
	var x_radius: int = mini(dispersal_radius, grid.width - 1)
	var y_radius: int = mini(dispersal_radius, grid.height - 1)
	var min_x: int = maxi(0, center.x - x_radius)
	var max_x: int = mini(grid.width - 1, center.x + x_radius)
	var min_y: int = maxi(0, center.y - y_radius)
	var max_y: int = mini(grid.height - 1, center.y + y_radius)
	for y: int in range(min_y, max_y + 1):
		for x: int in range(min_x, max_x + 1):
			var coordinates: Vector2i = Vector2i(x, y)
			if coordinates == center:
				continue
			var dx: int = absi(x - center.x)
			var dy: int = absi(y - center.y)
			if neighborhood_type == SimulationEnums.NeighborhoodType.VON_NEUMANN_4:
				if dx + dy > dispersal_radius:
					continue
			# The clipped rectangle already satisfies Chebyshev radius.
			neighbors.append(coordinates)
	return neighbors


static func get_distance_in_tiles(
	from_coordinates: Vector2i,
	to_coordinates: Vector2i
) -> float:
	var dx: float = float(to_coordinates.x) - float(from_coordinates.x)
	var dy: float = float(to_coordinates.y) - float(from_coordinates.y)
	return sqrt(dx * dx + dy * dy)
