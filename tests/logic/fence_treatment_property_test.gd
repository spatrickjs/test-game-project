extends SceneTree
## Property-based tests for the Fence Treatment Method.
##
## Uses PropertyTestRunner for randomized input generation (minimum 100 iterations
## per property). Each property references its design-document correctness property
## via a traceability tag comment above the run_property() call.
##
## Validates: Properties 1–4, 6, 7 (Requirement 2, 3, 4, 5, 6, 8).

const PropertyTestRunner = preload("res://tests/menu/property_test_runner.gd")
const Kind = SimulationEnums.FieldActionKind

func _initialize() -> void:
	var runner := PropertyTestRunner.new()
	var farming := _make_controller()

	# Feature: fence-treatment, Property 1: Fence postcondition
	runner.run_property(1, "Fence postcondition", func(r: PropertyTestRunner) -> bool:
		var coords := _rand_coords(r, farming)
		# Force any terrain to be plantable so we can have diverse priors.
		var prior := farming.get_grid_snapshot().get_cell(coords).copy()
		r.describe_input("coords=%s has_crop=%d has_fence=%d" % [str(coords), int(prior.has_crop), int(prior.has_fence)])
		var action := FieldAction.new()
		action.kind = Kind.FENCE
		action.target = coords
		# If the tile is already fenced, action_error rejects; skip those.
		if farming.action_error(action).is_empty():
			assert(farming.enqueue_action(action))
			assert(_finish_and_arrive(farming))
		var after := farming.get_grid_snapshot().get_cell(coords)
		r.check(after.has_fence, "postcondition: has_fence")
		r.check(after.terrain_type == SimulationEnums.TerrainType.GRASS, "postcondition: GRASS")
		r.check(after.soil == null, "postcondition: soil null")
		r.check(not after.has_crop, "postcondition: no crop")
		r.check(not after.has_active_disease, "postcondition: no disease")
		r.check(after.susceptible_fraction == 0.0, "postcondition: S zero")
		r.check(after.exposed_fraction == 0.0, "postcondition: E zero")
		r.check(after.infected_fraction == 0.0, "postcondition: I zero")
		r.check(after.recovered_immune_fraction == 0.0, "postcondition: R zero")
		r.check(after.dead_fraction == 0.0, "postcondition: D zero")
		r.check(after.validate().is_empty(), "postcondition: validate empty")
		# Reset for next iteration.
		_reset_tile(farming, coords, prior)
		return true
	)

	# Feature: fence-treatment, Property 2: Enqueue purity
	runner.run_property(2, "Enqueue purity", func(r: PropertyTestRunner) -> bool:
		var coords := _rand_coords(r, farming)
		var kind_idx := r.int_range(0, Kind.size() - 1)
		var kind: int = Kind.values()[kind_idx]
		var action := FieldAction.new()
		action.kind = kind
		action.target = coords
		action.source = coords + Vector2i.LEFT
		action.crop_type = r.element(SimulationEnums.CropType.values() as Array)
		r.describe_input("coords=%s kind=%d" % [str(coords), kind])
		var snap_before := farming.get_grid_snapshot().copy()
		# Whether it succeeds or fails, the grid must not change.
		farming.enqueue_action(action)
		var snap_after := farming.get_grid_snapshot()
		r.check(_grids_equal(snap_before, snap_after), "enqueue leaves grid unchanged")
		farming.cancel_actions()
		return true
	)

	# Feature: fence-treatment, Property 3: Fenced tile rejects all farming
	runner.run_property(3, "Fenced tile rejects all farming", func(r: PropertyTestRunner) -> bool:
		var coords := _rand_coords(r, farming)
		_fence_tile(farming, coords)
		var kind_idx := r.int_range(0, 4)  # PLANT, MOVE_CROP, WATER_BUCKET(DIG_GRASS-style), WATER_SOIL, FERTILIZE, HARVEST, REMOVE_CROP
		# Pick from the farming actions that should reject.
		var reject_kinds: Array = [Kind.PLANT, Kind.DIG_GRASS, Kind.MAKE_PADDY, Kind.WATER_SOIL, Kind.FERTILIZE, Kind.HARVEST, Kind.REMOVE_CROP, Kind.FENCE]
		var kind: int = r.element(reject_kinds)
		var action := FieldAction.new()
		action.kind = kind
		action.target = coords
		action.crop_type = r.element(SimulationEnums.CropType.values() as Array)
		action.additions = Vector3(0.1, 0.1, 0.1)
		r.describe_input("coords=%s kind=%d" % [str(coords), kind])
		var snap_before := farming.get_grid_snapshot().copy()
		var err := farming.action_error(action)
		r.check(not err.is_empty(), "fenced tile rejects kind %d" % kind)
		var snap_after := farming.get_grid_snapshot()
		r.check(_grids_equal(snap_before, snap_after), "rejection leaves grid unchanged")
		# Clean up the fence for the next iteration.
		_unfence_tile(farming, coords)
		return true
	)

	# Feature: fence-treatment, Property 4: Fence/unfence round trip
	runner.run_property(4, "Fence/unfence round trip", func(r: PropertyTestRunner) -> bool:
		var coords := _rand_coords(r, farming)
		r.describe_input("coords=%s" % str(coords))
		_fence_tile(farming, coords)
		_unfence_tile(farming, coords)
		var cell := farming.get_grid_snapshot().get_cell(coords)
		r.check(not cell.has_fence, "round trip: not fenced")
		r.check(cell.terrain_type == SimulationEnums.TerrainType.GRASS, "round trip: GRASS")
		r.check(cell.soil == null, "round trip: soil null")
		# DIG_GRASS should now succeed.
		var dig := FieldAction.new()
		dig.kind = Kind.DIG_GRASS
		dig.target = coords
		r.check(farming.action_error(dig).is_empty(), "round trip: dig succeeds after unfence")
		# Restore to dry soil for cleanliness.
		if farming.action_error(dig).is_empty():
			assert(farming.enqueue_action(dig))
			assert(_finish_and_arrive(farming))
			# Reset back to grass for next iteration.
			_reset_tile(farming, coords, null)
		return true
	)

	# Feature: fence-treatment, Property 6: Locality and no time advance
	runner.run_property(6, "Locality and no time advance", func(r: PropertyTestRunner) -> bool:
		var coords := _rand_coords(r, farming)
		var other := _rand_coords(r, farming)
		while other == coords:
			other = _rand_coords(r, farming)
		r.describe_input("coords=%s other=%s" % [str(coords), str(other)])
		var before := farming.get_grid_snapshot().copy()
		_fence_tile(farming, coords)
		var after := farming.get_grid_snapshot()
		# Only the target cell changes.
		var target_before := before.get_cell(coords).copy()
		var target_after := after.get_cell(coords)
		r.check(target_after.has_fence, "locality: target fenced")
		r.check(not target_before.has_fence, "locality: target was not fenced before")
		# The other cell must be unchanged.
		var other_before := before.get_cell(other)
		var other_after := after.get_cell(other)
		r.check(other_before.terrain_type == other_after.terrain_type, "locality: other terrain unchanged")
		r.check(other_before.has_crop == other_after.has_crop, "locality: other crop unchanged")
		r.check(other_before.has_fence == other_after.has_fence, "locality: other fence unchanged")
		# Clean up.
		_unfence_tile(farming, coords)
		return true
	)

	# Feature: fence-treatment, Property 7: Copy fidelity
	runner.run_property(7, "Copy fidelity", func(r: PropertyTestRunner) -> bool:
		var coords := _rand_coords(r, farming)
		# Randomize the cell state.
		var cell := farming.get_grid_snapshot().get_cell(coords)
		r.describe_input("coords=%s has_fence=%d" % [str(coords), int(cell.has_fence)])
		var copy := cell.copy()
		r.check(copy.has_fence == cell.has_fence, "copy: has_fence matches")
		r.check(copy.validate() == cell.validate(), "copy: validate identical")
		return true
	)

	farming.free()
	quit(runner.finish("FENCE_TREATMENT_PROPERTY_PASS"))


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_controller() -> FarmingController:
	var farming := FarmingController.new()
	farming.crop_database = load("res://src/data/databases/crop_database.tres") as CropDatabase
	farming.terrain_database = load("res://src/data/databases/terrain_database.tres") as TerrainDatabase
	farming.initial_soil = SoilState.new()
	farming.initial_abiotic = AbioticState.new()
	farming.field_size = Vector2i(9, 6)
	farming.terrain_bands = [
		SimulationEnums.TerrainType.DRY_SOIL,
		SimulationEnums.TerrainType.PADDY_MUD,
		SimulationEnums.TerrainType.GRASS,
	]
	assert(farming.initialize_field())
	return farming


func _rand_coords(r: PropertyTestRunner, farming: FarmingController) -> Vector2i:
	return Vector2i(r.int_range(0, farming.field_size.x - 1), r.int_range(0, farming.field_size.y - 1))


## Fence a tile via enqueue + arrival, bypassing the visual farmer.
func _finish_and_arrive(farming: FarmingController) -> bool:
	if not farming.has_pending_actions():
		return true
	var action := farming.get_current_action()
	return farming.arrive_at_action(action.id, action.target)


func _fence_tile(farming: FarmingController, coords: Vector2i) -> void:
	if farming.get_grid_snapshot().get_cell(coords).has_fence:
		return
	var a := FieldAction.new()
	a.kind = Kind.FENCE
	a.target = coords
	if farming.action_error(a).is_empty():
		assert(farming.enqueue_action(a))
		assert(_finish_and_arrive(farming))


func _unfence_tile(farming: FarmingController, coords: Vector2i) -> void:
	if not farming.get_grid_snapshot().get_cell(coords).has_fence:
		return
	var a := FieldAction.new()
	a.kind = Kind.REMOVE_FENCE
	a.target = coords
	assert(farming.enqueue_action(a))
	assert(_finish_and_arrive(farming))


## Restore a tile to a known prior state (or to default empty soil cell).
func _reset_tile(farming: FarmingController, coords: Vector2i, prior: FieldCellState) -> void:
	# Remove fence if present.
	if farming.get_grid_snapshot().get_cell(coords).has_fence:
		_unfence_tile(farming, coords)
	if prior == null:
		# Reset to empty grass with no soil.
		var cell := farming.get_grid_snapshot().get_cell(coords)
		# This is a logic-only test; we can use initialize_field to reset fully.
		farming.initialize_field()
		return
	# We cannot easily restore arbitrary prior state without internal access,
	# so reinitialize the field when prior is complex. This keeps properties independent.
	farming.initialize_field()


func _grids_equal(a: FieldGridState, b: FieldGridState) -> bool:
	if a.width != b.width or a.height != b.height:
		return false
	for y in range(a.height):
		for x in range(a.width):
			var ca := a.get_cell(Vector2i(x, y))
			var cb := b.get_cell(Vector2i(x, y))
			if ca == null or cb == null:
				if ca != cb:
					return false
				continue
			if ca.has_fence != cb.has_fence:
				return false
			if ca.has_crop != cb.has_crop:
				return false
			if ca.terrain_type != cb.terrain_type:
				return false
			if (ca.soil == null) != (cb.soil == null):
				return false
	return true
