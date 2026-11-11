extends SceneTree
## Unit tests for FieldGridQueries.fence_connections and fence_shape.
## Covers R1, R2, R5, R6: all 15 outline rows, OOB neighbor, diagonal, non-fence.

var _failures: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_no_neighbors()
	_test_single_cardinals()
	_test_straight_ns()
	_test_straight_ew()
	_test_corners()
	_test_t_shapes()
	_test_cross()
	_test_oob_neighbor()
	_test_diagonal_does_not_connect()
	_test_non_fence_does_not_connect()
	_test_null_grid()
	_test_no_fence_cell()
	_test_fence_shape()

	for failure: String in _failures:
		printerr("FAIL: " + failure)
	if _failures.is_empty():
		print("FENCE_CONNECTIONS_PASS")
	quit(0 if _failures.is_empty() else 1)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_grid(w: int, h: int) -> FieldGridState:
	var g: FieldGridState = FieldGridState.new()
	g.initialize(w, h, AbioticState.new())
	return g


func _fence(g: FieldGridState, coords: Vector2i) -> void:
	var cell: FieldCellState = g.get_cell(coords)
	if cell == null:
		return
	cell.terrain_type = SimulationEnums.TerrainType.GRASS
	cell.soil = null
	cell.has_crop = false
	cell.reset_crop_state()
	cell.has_fence = true


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)


const N: int = FieldGridQueries.FENCE_BIT_N
const E: int = FieldGridQueries.FENCE_BIT_E
const S: int = FieldGridQueries.FENCE_BIT_S
const W: int = FieldGridQueries.FENCE_BIT_W


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

## Scenario: no fenced neighbors → mask 0, shape POST.
func _test_no_neighbors() -> void:
	var g: FieldGridState = _make_grid(11, 11)
	_fence(g, Vector2i(5, 5))
	var mask: int = FieldGridQueries.fence_connections(g, Vector2i(5, 5))
	_check(mask == 0, "no neighbors: mask == 0, got %d" % mask)


## Scenarios: single cardinal fences → mask has one bit.
func _test_single_cardinals() -> void:
	for entry: Array in [
		[Vector2i(5, 4), N, "N"],
		[Vector2i(6, 5), E, "E"],
		[Vector2i(5, 6), S, "S"],
		[Vector2i(4, 5), W, "W"],
	]:
		var neighbor: Vector2i = entry[0] as Vector2i
		var expected_mask: int = entry[1] as int
		var label: String = entry[2] as String
		var g: FieldGridState = _make_grid(11, 11)
		_fence(g, Vector2i(5, 5))
		_fence(g, neighbor)
		var mask: int = FieldGridQueries.fence_connections(g, Vector2i(5, 5))
		_check(mask == expected_mask, "single %s: expected mask %d got %d" % [label, expected_mask, mask])


## Scenario: N,S → straight (mask 5).
func _test_straight_ns() -> void:
	var g: FieldGridState = _make_grid(11, 11)
	_fence(g, Vector2i(5, 5))
	_fence(g, Vector2i(5, 4))
	_fence(g, Vector2i(5, 6))
	var mask: int = FieldGridQueries.fence_connections(g, Vector2i(5, 5))
	_check(mask == N | S, "N+S straight: expected %d got %d" % [N | S, mask])


## Scenario: E,W → straight (mask 10).
func _test_straight_ew() -> void:
	var g: FieldGridState = _make_grid(11, 11)
	_fence(g, Vector2i(5, 5))
	_fence(g, Vector2i(6, 5))
	_fence(g, Vector2i(4, 5))
	var mask: int = FieldGridQueries.fence_connections(g, Vector2i(5, 5))
	_check(mask == E | W, "E+W straight: expected %d got %d" % [E | W, mask])


## Scenarios: two adjacent neighbors → corners.
func _test_corners() -> void:
	for entry: Array in [
		[[Vector2i(5,4), Vector2i(6,5)], N|E, "N+E corner"],
		[[Vector2i(6,5), Vector2i(5,6)], E|S, "E+S corner"],
		[[Vector2i(5,6), Vector2i(4,5)], S|W, "S+W corner"],
		[[Vector2i(4,5), Vector2i(5,4)], W|N, "W+N corner"],
	]:
		var neighbors: Array = entry[0] as Array
		var expected_mask: int = entry[1] as int
		var label: String = entry[2] as String
		var g: FieldGridState = _make_grid(11, 11)
		_fence(g, Vector2i(5, 5))
		for nb: Variant in neighbors:
			_fence(g, nb as Vector2i)
		var mask: int = FieldGridQueries.fence_connections(g, Vector2i(5, 5))
		_check(mask == expected_mask, "%s: expected %d got %d" % [label, expected_mask, mask])


## Scenarios: three cardinal neighbors → T shapes.
func _test_t_shapes() -> void:
	for entry: Array in [
		[[Vector2i(5,4), Vector2i(6,5), Vector2i(5,6)], N|E|S, "N+E+S T"],
		[[Vector2i(6,5), Vector2i(5,6), Vector2i(4,5)], E|S|W, "E+S+W T"],
		[[Vector2i(5,6), Vector2i(4,5), Vector2i(5,4)], S|W|N, "S+W+N T"],
		[[Vector2i(4,5), Vector2i(5,4), Vector2i(6,5)], W|N|E, "W+N+E T"],
	]:
		var neighbors: Array = entry[0] as Array
		var expected_mask: int = entry[1] as int
		var label: String = entry[2] as String
		var g: FieldGridState = _make_grid(11, 11)
		_fence(g, Vector2i(5, 5))
		for nb: Variant in neighbors:
			_fence(g, nb as Vector2i)
		var mask: int = FieldGridQueries.fence_connections(g, Vector2i(5, 5))
		_check(mask == expected_mask, "%s: expected %d got %d" % [label, expected_mask, mask])


## Scenario: all four cardinal neighbors → cross (mask 15).
func _test_cross() -> void:
	var g: FieldGridState = _make_grid(11, 11)
	_fence(g, Vector2i(5, 5))
	_fence(g, Vector2i(5, 4))
	_fence(g, Vector2i(6, 5))
	_fence(g, Vector2i(5, 6))
	_fence(g, Vector2i(4, 5))
	var mask: int = FieldGridQueries.fence_connections(g, Vector2i(5, 5))
	_check(mask == N|E|S|W, "cross: expected 15 got %d" % mask)


## Scenario: neighbor outside grid → no bit (R5).
func _test_oob_neighbor() -> void:
	var g: FieldGridState = _make_grid(11, 11)
	_fence(g, Vector2i(0, 0))
	# N neighbor (0,-1) is OOB; E neighbor (1,0) has no fence.
	var mask: int = FieldGridQueries.fence_connections(g, Vector2i(0, 0))
	_check(mask == 0, "OOB neighbor: mask == 0, got %d" % mask)


## Scenario: diagonal fence does NOT contribute (R6).
func _test_diagonal_does_not_connect() -> void:
	var g: FieldGridState = _make_grid(11, 11)
	_fence(g, Vector2i(5, 5))
	_fence(g, Vector2i(6, 6))  # diagonal SE
	_fence(g, Vector2i(4, 4))  # diagonal NW
	var mask: int = FieldGridQueries.fence_connections(g, Vector2i(5, 5))
	_check(mask == 0, "diagonal fence: mask == 0, got %d" % mask)


## Scenario: non-fence neighbor does NOT contribute (R5).
func _test_non_fence_does_not_connect() -> void:
	var g: FieldGridState = _make_grid(11, 11)
	_fence(g, Vector2i(5, 5))
	# (6,5) has terrain but no fence — default grass cell.
	var mask: int = FieldGridQueries.fence_connections(g, Vector2i(5, 5))
	_check(mask == 0, "non-fence neighbor: mask == 0, got %d" % mask)


## Null grid returns 0 safely.
func _test_null_grid() -> void:
	var mask: int = FieldGridQueries.fence_connections(null, Vector2i(5, 5))
	_check(mask == 0, "null grid: mask == 0, got %d" % mask)


## Non-fence cell at coords returns 0.
func _test_no_fence_cell() -> void:
	var g: FieldGridState = _make_grid(11, 11)
	# Default cell has no fence.
	var mask: int = FieldGridQueries.fence_connections(g, Vector2i(5, 5))
	_check(mask == 0, "no-fence cell: mask == 0, got %d" % mask)


## fence_shape returns expected shapes for all relevant masks (R2).
func _test_fence_shape() -> void:
	var FenceShape: Dictionary = {
		"POST": FieldGridQueries.FenceShape.POST,
		"END": FieldGridQueries.FenceShape.END,
		"STRAIGHT": FieldGridQueries.FenceShape.STRAIGHT,
		"CORNER": FieldGridQueries.FenceShape.CORNER,
		"T": FieldGridQueries.FenceShape.T,
		"CROSS": FieldGridQueries.FenceShape.CROSS,
	}
	# (mask, expected_shape_name)
	for entry: Array in [
		[0,       "POST"],
		[N,       "END"],
		[E,       "END"],
		[S,       "END"],
		[W,       "END"],
		[N|S,     "STRAIGHT"],
		[E|W,     "STRAIGHT"],
		[N|E,     "CORNER"],
		[E|S,     "CORNER"],
		[S|W,     "CORNER"],
		[W|N,     "CORNER"],
		[N|E|S,   "T"],
		[E|S|W,   "T"],
		[S|W|N,   "T"],
		[W|N|E,   "T"],
		[N|E|S|W, "CROSS"],
	]:
		var mask: int = entry[0] as int
		var shape_name: String = entry[1] as String
		var shape: FieldGridQueries.FenceShape = FieldGridQueries.fence_shape(mask)
		_check(shape == FenceShape[shape_name], "fence_shape(%d) expected %s got %d" % [mask, shape_name, shape])
