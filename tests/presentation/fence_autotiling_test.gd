extends SceneTree
## Presentation tests for Fence Auto-tiling.
## Validates R3, R4, R7: atlas coords per connection mask; place/remove neighbor repaint.
## Mask bit constants: N=1, E=2, S=4, W=8.
const GameplayFixture = preload("res://tests/logic/gameplay_test_fixture.gd")
const QueueDriver = preload("res://tests/logic/queued_action_test_driver.gd")
const Kind = SimulationEnums.FieldActionKind

const N: int = FieldGridQueries.FENCE_BIT_N  # 1
const E: int = FieldGridQueries.FENCE_BIT_E  # 2
const S: int = FieldGridQueries.FENCE_BIT_S  # 4
const W: int = FieldGridQueries.FENCE_BIT_W  # 8

var _failures: PackedStringArray = PackedStringArray()
var _scene: FieldPrototypePresenter
var _farming: FarmingController
var _world: FieldWorldView


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	_scene = (load("res://field_prototype.tscn") as PackedScene).instantiate() as FieldPrototypePresenter
	GameplayFixture.prepare(_scene, false)
	_scene.farming_controller.terrain_bands = [SimulationEnums.TerrainType.GRASS]
	root.add_child(_scene)
	GameplayFixture.start(_scene)
	for _frame: int in range(5):
		await process_frame
	_farming = _scene.farming_controller
	_world = _scene.world_view
	_world.farmer_agent.set_process(false)
	(_scene.get_node("HUD") as CanvasLayer).hide()

	# Abort early if the basic fence setup is missing.
	if _world.fence_layer == null or _world.fence_visual == null:
		_failures.append("fence_layer or fence_visual not configured; skipping autotile tests")
		_finish()
		return

	# ------------------------------------------------------------------
	# Precondition: tile_mapping must have all 16 entries.
	# ------------------------------------------------------------------
	var mapping: Dictionary = _world.fence_visual.tile_mapping
	_check(mapping.size() == 16, "tile_mapping has 16 entries, got %d" % mapping.size())
	if mapping.size() != 16:
		_finish()
		return

	# ------------------------------------------------------------------
	# R7: each mask paints the mapped atlas tile.
	# Use grass coordinates (y-band where terrain is GRASS).
	# ------------------------------------------------------------------
	var snap: FieldGridState = _farming.get_grid_snapshot()
	var gy: int = snap.height - 1
	# Need at least 3 columns: col 1 is center, col 0/2 are neighbors.
	_check(snap.width >= 3, "grid wide enough for neighbor tests")
	var center: Vector2i = Vector2i(1, gy)
	var left: Vector2i  = Vector2i(0, gy)
	var right: Vector2i = Vector2i(2, gy)

	# Fence center only → mask 0 (post).
	await _place_fence(center)
	_check_atlas(center, 0, "isolated post → mask 0")

	# Add fence to the left → center gains W connection (mask 8).
	await _place_fence(left)
	_check_atlas(center, W, "center with W neighbor → mask 8")
	# Left cell also gets E connection (mask 2).
	_check_atlas(left, E, "left cell with E neighbor → mask 2")

	# Add fence to the right → center gains W+E connections (mask 10).
	await _place_fence(right)
	_check_atlas(center, E | W, "center with E+W neighbors → mask 10 (straight)")
	# Right cell gets W connection (mask 8).
	_check_atlas(right, W, "right cell with W neighbor → mask 8")

	# ------------------------------------------------------------------
	# R4: removing center updates remaining neighbors.
	# ------------------------------------------------------------------
	await _remove_fence(center)
	# Left and right cells should now have mask 0 (post, no connections).
	_check_atlas(left,  0, "left post after center removed → mask 0")
	_check_atlas(right, 0, "right post after center removed → mask 0")

	# ------------------------------------------------------------------
	# R3: placing a fence updates existing fenced neighbors.
	# Already tested above (place center, place left, check center atlas changes).
	# Additional explicit scenario: place center after left+right → straight immediately.
	# ------------------------------------------------------------------
	# left and right are still fenced.
	await _place_fence(center)
	_check_atlas(center, E | W, "center placed between existing fences → straight E+W immediately")

	# ------------------------------------------------------------------
	# Use a separate area so the straight fence above cannot affect the cross.
	# ------------------------------------------------------------------
	_check(snap.width >= 6 and snap.height >= 3, "grid wide enough for junction tests")
	await _test_cross_transitions(Vector2i(4, snap.height - 2))

	# ------------------------------------------------------------------
	# Null-safety regression: render_fences with null fence_visual must not crash (R9).
	# ------------------------------------------------------------------
	var saved_visual: FenceVisual = _world.fence_visual
	_world.fence_visual = null
	_world.render_fences(_farming.get_grid_snapshot())
	_check(true, "render_fences with null fence_visual did not crash")
	_world.fence_visual = saved_visual

	(_scene.get_node("HUD") as CanvasLayer).show()
	_scene.free()
	await process_frame
	_finish()


func _test_cross_transitions(c: Vector2i) -> void:
	# Place center.
	await _place_fence(c)
	_check_atlas(c, 0, "extended: isolated center → mask 0")

	# Add N → mask 1 (end-N).
	var n_cell: Vector2i = c + Vector2i.UP
	await _place_fence(n_cell)
	_check_atlas(c, N, "extended: N only → mask 1")

	# Add E → mask 3 (corner N+E).
	var e_cell: Vector2i = c + Vector2i.RIGHT
	await _place_fence(e_cell)
	_check_atlas(c, N | E, "extended: N+E corner → mask 3")

	# Add S → mask 7 (T N+E+S).
	var s_cell: Vector2i = c + Vector2i.DOWN
	await _place_fence(s_cell)
	_check_atlas(c, N | E | S, "extended: N+E+S T → mask 7")

	# Add W → mask 15 (cross).
	var w_cell: Vector2i = c + Vector2i.LEFT
	await _place_fence(w_cell)
	_check_atlas(c, N | E | S | W, "extended: cross → mask 15")

	# The atlas uses a mirrored tile for the E+S+W junction.
	await _remove_fence(n_cell)
	_check_atlas(c, E | S | W, "extended: remove N → mirrored T mask 14")
	await _place_fence(n_cell)

	# Remove W → back to T (mask 7).
	await _remove_fence(w_cell)
	_check_atlas(c, N | E | S, "extended: remove W → back to T mask 7")

	# Remove center → neighbors lose their connection to center.
	await _remove_fence(c)
	_check_atlas(n_cell, 0, "extended: N cell loses S connection after center removed")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _action(kind: SimulationEnums.FieldActionKind, target: Vector2i) -> FieldAction:
	var a: FieldAction = FieldAction.new()
	a.kind = kind
	a.target = target
	a.crop_type = SimulationEnums.CropType.CORN
	return a


func _place_fence(coords: Vector2i) -> void:
	var snap: FieldGridState = _farming.get_grid_snapshot()
	var cell: FieldCellState = snap.get_cell(coords)
	if cell != null and cell.has_fence:
		return  # Already fenced; skip.
	if _farming.enqueue_action(_action(Kind.FENCE, coords)):
		QueueDriver.finish(_scene)
	await process_frame


func _remove_fence(coords: Vector2i) -> void:
	var snap: FieldGridState = _farming.get_grid_snapshot()
	var cell: FieldCellState = snap.get_cell(coords)
	if cell == null or not cell.has_fence:
		return  # Not fenced; skip.
	if _farming.enqueue_action(_action(Kind.REMOVE_FENCE, coords)):
		QueueDriver.finish(_scene)
	await process_frame


## Assert that fence_layer paints the atlas tile mapped to expected_mask at coords.
func _check_atlas(coords: Vector2i, expected_mask: int, label: String) -> void:
	if _world.fence_layer == null or _world.fence_visual == null:
		_check(false, label + " [fence_layer or fence_visual null]")
		return
	var mapping: Dictionary = _world.fence_visual.tile_mapping
	if mapping.is_empty():
		_check(false, label + " [tile_mapping empty]")
		return
	var entry: Array = mapping.get(expected_mask, []) as Array
	if entry.size() < 3:
		_check(false, label + " [no mapping entry for mask %d]" % expected_mask)
		return
	var expected_source_id: int = int(entry[0])
	var expected_coords: Vector2i = entry[1] as Vector2i
	var expected_alternative: int = int(entry[2])
	var actual_source: int = _world.fence_layer.get_cell_source_id(coords)
	var actual_coords: Vector2i = _world.fence_layer.get_cell_atlas_coords(coords)
	var actual_alternative: int = _world.fence_layer.get_cell_alternative_tile(coords)
	_check(
		actual_source == expected_source_id and actual_coords == expected_coords,
		label + " [mask %d: expected source=%d coords=%s, got source=%d coords=%s]" % [
			expected_mask, expected_source_id, str(expected_coords),
			actual_source, str(actual_coords)
		]
	)
	_check(actual_alternative == expected_alternative,
		"%s [expected alternative %d, got %d]" % [label, expected_alternative, actual_alternative])


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)


func _finish() -> void:
	for failure: String in _failures:
		printerr("FAIL: " + failure)
	if _failures.is_empty():
		print("FENCE_AUTOTILING_PASS")
	quit(0 if _failures.is_empty() else 1)
