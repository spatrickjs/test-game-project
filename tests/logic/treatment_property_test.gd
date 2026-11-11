extends SceneTree
## Property-based tests for the treatment system (Task 16).
## Tests invariants: no stacking, mismatch no-op, bounds, compartment sum,
## expiry, monotonic resistance, enhancer neutrality, determinism, cost
## accounting, queue gating, save round-trip.

var failures: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _initialize() -> void:
	_rng.seed = 12345
	_prop_no_stacking()
	_prop_mismatch_noop()
	_prop_bounds()
	_prop_compartment_sum_invariant()
	_prop_expiry_exact()
	_prop_monotonic_resistance()
	_prop_enhancer_neutrality()
	_prop_determinism()
	_prop_cost_accounting()
	_prop_queue_gating()
	_prop_save_roundtrip()
	if failures == 0:
		print("TREATMENT_PROPERTY_PASS")
	quit(0 if failures == 0 else 1)


func _make_setup() -> Dictionary:
	var tc: TreatmentController = TreatmentController.new()
	tc.treatment_config = load("res://src/data/treatments/treatment_config.tres") as TreatmentConfig
	tc.disease_database = load("res://src/data/databases/default_disease_database.tres") as DiseaseDatabase
	tc.treatment_state = TreatmentState.new()
	var grid: FieldGridState = FieldGridState.new()
	grid.initialize(7, 7, AbioticState.new())
	for y: int in range(7):
		for x: int in range(7):
			var cell: FieldCellState = grid.get_cell(Vector2i(x, y))
			cell.terrain_type = SimulationEnums.TerrainType.DRY_SOIL
			cell.soil = SoilState.new()
			cell.has_crop = true
			cell.crop_type = SimulationEnums.CropType.RICE
			cell.reset_crop_state()
	return {"tc": tc, "grid": grid}


func _infect(grid: FieldGridState, coords: Vector2i, disease_id: int) -> void:
	var cell: FieldCellState = grid.get_cell(coords)
	cell.has_active_disease = true
	cell.active_disease_id = disease_id as SimulationEnums.DiseaseId
	cell.sir_state = SimulationEnums.SIRState.I
	cell.infected_fraction = 0.2
	cell.susceptible_fraction = 0.8


func _action(kind: int, target: Vector2i) -> FieldAction:
	var a: FieldAction = FieldAction.new()
	a.kind = kind
	a.target = target
	return a


# Property: No stacking — applying the same treatment twice never gives stronger modifier
func _prop_no_stacking() -> void:
	for trial: int in range(20):
		var s: Dictionary = _make_setup()
		var tc: TreatmentController = s["tc"]
		var grid: FieldGridState = s["grid"]
		var target: Vector2i = Vector2i(_rng.randi_range(1, 5), _rng.randi_range(1, 5))
		_infect(grid, target, SimulationEnums.DiseaseId.RICE_BLAST)
		# Apply once
		tc.commit_treatment(_action(SimulationEnums.FieldActionKind.APPLY_FUNGICIDE, target), grid, 0)
		var mods1: TreatmentModifiers = TreatmentResolver.resolve(target, tc.treatment_state, tc.treatment_config)
		# Apply again (refresh, same potency)
		tc.treatment_state.set_cooldown(&"fungicide", 0)
		tc.commit_treatment(_action(SimulationEnums.FieldActionKind.APPLY_FUNGICIDE, target), grid, 0)
		var mods2: TreatmentModifiers = TreatmentResolver.resolve(target, tc.treatment_state, tc.treatment_config)
		if mods2.hazard_mult < mods1.hazard_mult - 0.001:
			fail("No stacking: second application should not be stronger, %f < %f" % [mods2.hazard_mult, mods1.hazard_mult])
			return


# Property: Mismatch no-op — a mismatched cell's modifiers are unchanged
func _prop_mismatch_noop() -> void:
	for trial: int in range(20):
		var s: Dictionary = _make_setup()
		var tc: TreatmentController = s["tc"]
		var grid: FieldGridState = s["grid"]
		var target: Vector2i = Vector2i(_rng.randi_range(1, 5), _rng.randi_range(1, 5))
		_infect(grid, target, SimulationEnums.DiseaseId.BACTERIAL_LEAF_BLIGHT)
		# Apply fungicide (mismatch: bacterial vs fungal)
		tc.commit_treatment(_action(SimulationEnums.FieldActionKind.APPLY_FUNGICIDE, target), grid, 0)
		var mods: TreatmentModifiers = TreatmentResolver.resolve(target, tc.treatment_state, tc.treatment_config)
		if absf(mods.hazard_mult - 1.0) > 0.001:
			fail("Mismatch no-op: hazard_mult should be 1.0, got %f" % mods.hazard_mult)
			return
		if absf(mods.gamma_scale - 1.0) > 0.001:
			fail("Mismatch no-op: gamma_scale should be 1.0, got %f" % mods.gamma_scale)
			return


# Property: Bounds — resolved multipliers stay within configured clamps
func _prop_bounds() -> void:
	var config: TreatmentConfig = load("res://src/data/treatments/treatment_config.tres") as TreatmentConfig
	for trial: int in range(20):
		var s: Dictionary = _make_setup()
		var tc: TreatmentController = s["tc"]
		var grid: FieldGridState = s["grid"]
		var target: Vector2i = Vector2i(_rng.randi_range(1, 5), _rng.randi_range(1, 5))
		_infect(grid, target, SimulationEnums.DiseaseId.RICE_BLAST)
		# Apply fungicide + enhancer
		tc.commit_treatment(_action(SimulationEnums.FieldActionKind.APPLY_FUNGICIDE, target), grid, 0)
		tc.treatment_state.set_cooldown(&"enhancer", 0)
		tc.commit_treatment(_action(SimulationEnums.FieldActionKind.APPLY_ENHANCER, target), grid, 0)
		var mods: TreatmentModifiers = TreatmentResolver.resolve(target, tc.treatment_state, config)
		if mods.hazard_mult < config.min_hazard_mult - 0.001:
			fail("Bounds: hazard_mult below floor, %f < %f" % [mods.hazard_mult, config.min_hazard_mult])
			return
		if mods.gamma_scale > config.max_gamma_scale + 0.001:
			fail("Bounds: gamma_scale above ceiling, %f > %f" % [mods.gamma_scale, config.max_gamma_scale])
			return


# Property: Compartment sum invariant — fractions still sum to 1.0 after treated turns
func _prop_compartment_sum_invariant() -> void:
	var config: TreatmentConfig = load("res://src/data/treatments/treatment_config.tres") as TreatmentConfig
	var db: DiseaseDatabase = load("res://src/data/databases/default_disease_database.tres") as DiseaseDatabase
	var crops: CropDatabase = load("res://src/data/databases/crop_database.tres") as CropDatabase
	for algo: int in [0, 1]:
		for trial: int in range(5):
			var s: Dictionary = _make_setup()
			var tc: TreatmentController = s["tc"]
			var grid: FieldGridState = s["grid"]
			_infect(grid, Vector2i(3, 3), SimulationEnums.DiseaseId.RICE_BLAST)
			tc.commit_treatment(_action(SimulationEnums.FieldActionKind.APPLY_FUNGICIDE, Vector2i(3, 3)), grid, 0)
			var sim: SimulationController = SimulationController.new()
			sim.rng.seed = trial * 100
			sim.crop_database = crops
			sim.treatment_state = tc.treatment_state
			sim.treatment_config = config
			sim.algorithm_override = algo
			for tick: int in range(5):
				if not sim.process_turn(grid, db):
					fail("Invariant: process_turn should succeed, got: %s" % sim.last_error)
					return
				tc.advance_turn(tick + 1)
			for y: int in range(7):
				for x: int in range(7):
					var cell: FieldCellState = grid.get_cell(Vector2i(x, y))
					if not cell.has_crop:
						continue
					var sum: float = cell.susceptible_fraction + cell.exposed_fraction + cell.infected_fraction + cell.recovered_immune_fraction + cell.dead_fraction
					if absf(sum - 1.0) > 0.001:
						fail("Invariant: fractions sum to %f at (%d,%d) algo %d" % [sum, x, y, algo])
						return


# Property: Expiry — effects vanish after exactly duration_turns completed turns
func _prop_expiry_exact() -> void:
	var config: TreatmentConfig = load("res://src/data/treatments/treatment_config.tres") as TreatmentConfig
	for t: TreatmentData in config.treatments:
		if t == null or t.treatment_id == &"insecticide":
			continue
		var s: Dictionary = _make_setup()
		var tc: TreatmentController = s["tc"]
		var grid: FieldGridState = s["grid"]
		var target: Vector2i = Vector2i(3, 3)
		# Infect for curative treatments
		if t.applies_to == TreatmentData.AppliesTo.INFECTED:
			_infect(grid, target, SimulationEnums.DiseaseId.RICE_BLAST if t.allowed_categories.has(0) else SimulationEnums.DiseaseId.BACTERIAL_LEAF_BLIGHT)
		# Apply
		var action: FieldAction = FieldAction.new()
		action.kind = TreatmentController.treatment_id_to_kind(t.treatment_id)
		action.target = target
		tc.commit_treatment(action, grid, 0)
		# Should still be active at duration - 1
		for i: int in range(t.duration_turns - 1):
			tc.advance_turn(i + 1)
		if tc.treatment_state.get_effect(target, t.treatment_id) == null:
			fail("Expiry: %s should still be active at turn %d" % [String(t.treatment_id), t.duration_turns - 1])
			continue
		# Should be expired at duration
		tc.advance_turn(t.duration_turns)
		if tc.treatment_state.get_effect(target, t.treatment_id) != null:
			fail("Expiry: %s should expire after %d turns" % [String(t.treatment_id), t.duration_turns])


# Property: Monotonic resistance — more uses never raise potency
func _prop_monotonic_resistance() -> void:
	var s: Dictionary = _make_setup()
	var tc: TreatmentController = s["tc"]
	var grid: FieldGridState = s["grid"]
	_infect(grid, Vector2i(0, 0), SimulationEnums.DiseaseId.RICE_BLAST)
	var prev_potency: float = 1.0
	for i: int in range(8):
		tc.treatment_state.set_cooldown(&"fungicide", 0)
		tc.commit_treatment(_action(SimulationEnums.FieldActionKind.APPLY_FUNGICIDE, Vector2i(0, 0)), grid, i)
		var e: TreatmentEffect = tc.treatment_state.get_effect(Vector2i(0, 0), &"fungicide")
		if e != null and e.potency > prev_potency + 0.001:
			fail("Monotonic resistance: potency increased at use %d: %f > %f" % [i, e.potency, prev_potency])
			return
		if e != null:
			prev_potency = e.potency


# Property: Enhancer neutrality — enhancer never changes infection status or gamma
func _prop_enhancer_neutrality() -> void:
	for trial: int in range(10):
		var s: Dictionary = _make_setup()
		var tc: TreatmentController = s["tc"]
		var grid: FieldGridState = s["grid"]
		var target: Vector2i = Vector2i(_rng.randi_range(1, 5), _rng.randi_range(1, 5))
		_infect(grid, target, SimulationEnums.DiseaseId.RICE_TUNGRO)
		var before_inf: float = grid.get_cell(target).infected_fraction
		var before_act: bool = grid.get_cell(target).has_active_disease
		tc.commit_treatment(_action(SimulationEnums.FieldActionKind.APPLY_ENHANCER, target), grid, 0)
		var cell: FieldCellState = grid.get_cell(target)
		if cell.infected_fraction != before_inf:
			fail("Enhancer neutrality: infection fraction changed")
			return
		if cell.has_active_disease != before_act:
			fail("Enhancer neutrality: active disease changed")
			return
		var mods: TreatmentModifiers = TreatmentResolver.resolve(target, tc.treatment_state, tc.treatment_config)
		if absf(mods.gamma_scale - 1.0) > 0.001:
			fail("Enhancer neutrality: gamma changed to %f" % mods.gamma_scale)
			return


# Property: Determinism — same seed and actions give the same state
func _prop_determinism() -> void:
	var config: TreatmentConfig = load("res://src/data/treatments/treatment_config.tres") as TreatmentConfig
	var db: DiseaseDatabase = load("res://src/data/databases/default_disease_database.tres") as DiseaseDatabase
	var crops: CropDatabase = load("res://src/data/databases/crop_database.tres") as CropDatabase
	for algo: int in [0, 1, 2]:
		var grid1: FieldGridState = FieldGridState.new()
		grid1.initialize(5, 5, AbioticState.new())
		var grid2: FieldGridState = FieldGridState.new()
		grid2.initialize(5, 5, AbioticState.new())
		for g: FieldGridState in [grid1, grid2]:
			for y: int in range(5):
				for x: int in range(5):
					var c: FieldCellState = g.get_cell(Vector2i(x, y))
					c.terrain_type = SimulationEnums.TerrainType.DRY_SOIL
					c.soil = SoilState.new()
					c.has_crop = true
					c.crop_type = SimulationEnums.CropType.RICE
					c.reset_crop_state()
			_infect(g, Vector2i(2, 2), SimulationEnums.DiseaseId.RICE_BLAST)
		var tc1: TreatmentController = _make_controller_for_prop(config)
		var tc2: TreatmentController = _make_controller_for_prop(config)
		tc1.commit_treatment(_action(SimulationEnums.FieldActionKind.APPLY_FUNGICIDE, Vector2i(2, 2)), grid1, 0)
		tc2.commit_treatment(_action(SimulationEnums.FieldActionKind.APPLY_FUNGICIDE, Vector2i(2, 2)), grid2, 0)
		var sim1: SimulationController = SimulationController.new()
		sim1.rng.seed = 77
		sim1.crop_database = crops
		sim1.treatment_state = tc1.treatment_state
		sim1.treatment_config = config
		sim1.algorithm_override = algo
		var sim2: SimulationController = SimulationController.new()
		sim2.rng.seed = 77
		sim2.crop_database = crops
		sim2.treatment_state = tc2.treatment_state
		sim2.treatment_config = config
		sim2.algorithm_override = algo
		for tick: int in range(5):
			sim1.process_turn(grid1, db)
			sim2.process_turn(grid2, db)
			tc1.advance_turn(tick + 1)
			tc2.advance_turn(tick + 1)
		for y: int in range(5):
			for x: int in range(5):
				var c1: FieldCellState = grid1.get_cell(Vector2i(x, y))
				var c2: FieldCellState = grid2.get_cell(Vector2i(x, y))
				if absf(c1.infected_fraction - c2.infected_fraction) > 0.0001:
					fail("Determinism: mismatch at (%d,%d) algo %d: %f vs %f" % [x, y, algo, c1.infected_fraction, c2.infected_fraction])
					return


func _make_controller_for_prop(config: TreatmentConfig) -> TreatmentController:
	var tc: TreatmentController = TreatmentController.new()
	tc.treatment_config = config
	tc.disease_database = load("res://src/data/databases/default_disease_database.tres") as DiseaseDatabase
	tc.treatment_state = TreatmentState.new()
	return tc


# Property: Cost accounting — rejected/discarded actions never spend resources
func _prop_cost_accounting() -> void:
	var s: Dictionary = _make_setup()
	var tc: TreatmentController = s["tc"]
	var grid: FieldGridState = s["grid"]
	_infect(grid, Vector2i(2, 2), SimulationEnums.DiseaseId.RICE_BLAST)
	# Set up with limited budget
	tc.resource_budget = 0
	# Cost is 0 for all treatments, so this should still work
	# But cooldown discard should not log usage
	tc.treatment_state.set_cooldown(&"fungicide", 5)
	var before_usage: int = tc.treatment_state.usage_count(TreatmentData.ResistanceGroup.FUNGICIDE, 10, 0)
	# Commit fails (on cooldown)
	tc.commit_treatment(_action(SimulationEnums.FieldActionKind.APPLY_FUNGICIDE, Vector2i(2, 2)), grid, 0)
	var after_usage: int = tc.treatment_state.usage_count(TreatmentData.ResistanceGroup.FUNGICIDE, 10, 0)
	if after_usage != before_usage:
		fail("Cost accounting: discarded action should not log usage, %d -> %d" % [before_usage, after_usage])


# Property: Queue gating — no treatment takes effect without a commit
func _prop_queue_gating() -> void:
	var s: Dictionary = _make_setup()
	var tc: TreatmentController = s["tc"]
	var grid: FieldGridState = s["grid"]
	_infect(grid, Vector2i(2, 2), SimulationEnums.DiseaseId.RICE_BLAST)
	# Preview only, never commit
	tc.preview(&"fungicide", Vector2i(2, 2), grid)
	if tc.treatment_state.effects.size() != 0:
		fail("Queue gating: preview should not create effects")
	# can_enqueue only, never commit
	var err: String = tc.can_enqueue(&"fungicide", Vector2i(2, 2), grid, 0)
	# No effects even though can_enqueue passed
	if tc.treatment_state.effects.size() != 0:
		fail("Queue gating: can_enqueue should not create effects")


# Property: Save round-trip — from_dict(to_dict(x)) equals x
func _prop_save_roundtrip() -> void:
	var state: TreatmentState = TreatmentState.new()
	var e: TreatmentEffect = TreatmentEffect.new()
	e.treatment_id = &"fungicide"
	e.cell = Vector2i(3, 4)
	e.remaining_turns = 2
	e.potency = 0.6
	e.applied_turn = 7
	state.put_effect(e)
	state.set_cooldown(&"bactericide", 3)
	state.log_usage(TreatmentData.ResistanceGroup.FUNGICIDE, 1)
	state.log_usage(TreatmentData.ResistanceGroup.FUNGICIDE, 2)
	state.log_enhancer_use(Vector2i(1, 1), 0)
	state.log_mistake(&"fungicide", 5, Vector2i(2, 3), 1)
	# Round-trip twice
	var rt1: TreatmentState = TreatmentState.from_dict(state.to_dict())
	var rt2: TreatmentState = TreatmentState.from_dict(rt1.to_dict())
	# Compare
	if rt2.effects.size() != state.effects.size():
		fail("Round-trip: effect count mismatch")
	if rt2.get_cooldown(&"bactericide") != 3:
		fail("Round-trip: cooldown mismatch")
	if rt2.usage_count(TreatmentData.ResistanceGroup.FUNGICIDE, 10, 2) != 2:
		fail("Round-trip: usage count mismatch")
	if rt2.enhancer_use_count(Vector2i(1, 1), 10, 0) != 1:
		fail("Round-trip: enhancer use count mismatch")
	if rt2.mistakes.size() != 1:
		fail("Round-trip: mistakes mismatch")
	var e2: TreatmentEffect = rt2.get_effect(Vector2i(3, 4), &"fungicide")
	if e2 == null or e2.remaining_turns != 2 or absf(e2.potency - 0.6) > 0.001:
		fail("Round-trip: effect data mismatch")


func fail(message: String) -> void:
	failures += 1
	printerr("FAIL: " + message)
