extends SceneTree
## Maps Gherkin scenarios from features/treatments.feature to executable tests.
## Each scenario is a test function that follows the Given/When/Then steps.

var failures: int = 0


func _initialize() -> void:
	_scenario_treatment_goes_through_queue()
	_scenario_treatment_takes_effect_on_arrival()
	_scenario_queue_cap()
	_scenario_cooldown_rejected()
	_scenario_fungicide_on_bacterial_nothing()
	_scenario_mixed_disease_area()
	_scenario_curative_on_healthy_not_mistake()
	_scenario_fungicide_reduces_transmission()
	_scenario_fungicide_lasts_3_turns()
	_scenario_bactericide_treats_bacterial()
	_scenario_protectant_lowers_susceptibility()
	_scenario_protectant_wears_off()
	_scenario_enhancer_raises_resilience()
	_scenario_repeated_enhancer_diminishing()
	_scenario_same_treatment_no_stack()
	_scenario_different_treatments_combine()
	_scenario_overusing_fungicide_weakens()
	_scenario_protectant_counts_toward_resistance()
	_scenario_resistance_decays()
	_scenario_save_and_load()
	_scenario_older_save_loads_empty()
	if failures == 0:
		print("TREATMENT_GHERKIN_PASS")
	quit(0 if failures == 0 else 1)


func _make_setup() -> Dictionary:
	var tc: TreatmentController = TreatmentController.new()
	tc.treatment_config = load("res://src/data/treatments/treatment_config.tres") as TreatmentConfig
	tc.disease_database = load("res://src/data/databases/default_disease_database.tres") as DiseaseDatabase
	tc.treatment_state = TreatmentState.new()
	var grid: FieldGridState = FieldGridState.new()
	grid.initialize(5, 5, AbioticState.new())
	for y: int in range(5):
		for x: int in range(5):
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


func _make_action(kind: int, target: Vector2i) -> FieldAction:
	var a: FieldAction = FieldAction.new()
	a.kind = kind
	a.target = target
	return a


# Scenario: Treatment goes through the work queue
func _scenario_treatment_goes_through_queue() -> void:
	var s: Dictionary = _make_setup()
	var tc: TreatmentController = s["tc"]
	var grid: FieldGridState = s["grid"]
	_infect(grid, Vector2i(2, 2), SimulationEnums.DiseaseId.RICE_BLAST)
	# Preview (no commit yet) - no effect should exist
	tc.preview(&"fungicide", Vector2i(2, 2), grid)
	if tc.treatment_state.effects.size() != 0:
		fail("Queue: preview should not create effects")


# Scenario: Treatment takes effect when the farmer arrives
func _scenario_treatment_takes_effect_on_arrival() -> void:
	var s: Dictionary = _make_setup()
	var tc: TreatmentController = s["tc"]
	var grid: FieldGridState = s["grid"]
	_infect(grid, Vector2i(2, 2), SimulationEnums.DiseaseId.RICE_BLAST)
	if not tc.commit_treatment(_make_action(SimulationEnums.FieldActionKind.APPLY_FUNGICIDE, Vector2i(2, 2)), grid, 0):
		fail("Arrival: commit should succeed")
	if tc.treatment_state.get_effect(Vector2i(2, 2), &"fungicide") == null:
		fail("Arrival: effect should be active")
	if tc.treatment_state.get_cooldown(&"fungicide") == 0:
		fail("Arrival: cooldown should start")


# Scenario: Queue cap per turn
func _scenario_queue_cap() -> void:
	var s: Dictionary = _make_setup()
	var tc: TreatmentController = s["tc"]
	var grid: FieldGridState = s["grid"]
	_infect(grid, Vector2i(0, 0), SimulationEnums.DiseaseId.RICE_BLAST)
	_infect(grid, Vector2i(4, 4), SimulationEnums.DiseaseId.RICE_BLAST)
	# Enqueue 2 (cap)
	var err1: String = tc.can_enqueue(&"fungicide", Vector2i(0, 0), grid, 0)
	if not err1.is_empty():
		fail("Queue cap: first enqueue should pass, got: %s" % err1)
	var err2: String = tc.can_enqueue(&"fungicide", Vector2i(4, 4), grid, 1)
	if not err2.is_empty():
		fail("Queue cap: second enqueue should pass, got: %s" % err2)
	# Third should fail
	var err3: String = tc.can_enqueue(&"fungicide", Vector2i(2, 2), grid, 2)
	if err3.is_empty():
		fail("Queue cap: third enqueue should be rejected")


# Scenario: Treatment on cooldown is rejected
func _scenario_cooldown_rejected() -> void:
	var s: Dictionary = _make_setup()
	var tc: TreatmentController = s["tc"]
	var grid: FieldGridState = s["grid"]
	_infect(grid, Vector2i(2, 2), SimulationEnums.DiseaseId.BACTERIAL_LEAF_BLIGHT)
	tc.treatment_state.set_cooldown(&"bactericide", 2)
	var err: String = tc.can_enqueue(&"bactericide", Vector2i(2, 2), grid, 0)
	if err.is_empty():
		fail("Cooldown: should be rejected when on cooldown")
	if not err.contains("cooldown"):
		fail("Cooldown: error should mention cooldown")


# Scenario: Fungicide on a bacterial disease does nothing
func _scenario_fungicide_on_bacterial_nothing() -> void:
	var s: Dictionary = _make_setup()
	var tc: TreatmentController = s["tc"]
	var grid: FieldGridState = s["grid"]
	_infect(grid, Vector2i(2, 2), SimulationEnums.DiseaseId.BACTERIAL_LEAF_BLIGHT)
	tc.commit_treatment(_make_action(SimulationEnums.FieldActionKind.APPLY_FUNGICIDE, Vector2i(2, 2)), grid, 0)
	if tc.treatment_state.get_effect(Vector2i(2, 2), &"fungicide") != null:
		fail("Fungicide on bacterial: no effect should be applied")
	if tc.treatment_state.mistakes.size() != 1:
		fail("Fungicide on bacterial: one mistake should be recorded")
	# Cost still spent (cooldown started)
	if tc.treatment_state.get_cooldown(&"fungicide") == 0:
		fail("Fungicide on bacterial: cost/cooldown should still be charged")


# Scenario: Mixed-disease area only affects matching cells
func _scenario_mixed_disease_area() -> void:
	var s: Dictionary = _make_setup()
	var tc: TreatmentController = s["tc"]
	var grid: FieldGridState = s["grid"]
	_infect(grid, Vector2i(2, 2), SimulationEnums.DiseaseId.RICE_BLAST)
	_infect(grid, Vector2i(2, 3), SimulationEnums.DiseaseId.BACTERIAL_LEAF_BLIGHT)
	tc.commit_treatment(_make_action(SimulationEnums.FieldActionKind.APPLY_FUNGICIDE, Vector2i(2, 2)), grid, 0)
	if tc.treatment_state.get_effect(Vector2i(2, 2), &"fungicide") == nil:
		fail("Mixed area: RICE_BLAST cell should have effect")
	if tc.treatment_state.get_effect(Vector2i(2, 3), &"fungicide") != null:
		fail("Mixed area: BLB cell should have no effect")
	if tc.treatment_state.mistakes.size() < 1:
		fail("Mixed area: at least one mistake should be recorded")


# Scenario: Curative treatment on a healthy cell is not a mistake
func _scenario_curative_on_healthy_not_mistake() -> void:
	var s: Dictionary = _make_setup()
	var tc: TreatmentController = s["tc"]
	var grid: FieldGridState = s["grid"]
	tc.commit_treatment(_make_action(SimulationEnums.FieldActionKind.APPLY_FUNGICIDE, Vector2i(2, 2)), grid, 0)
	if tc.treatment_state.mistakes.size() != 0:
		fail("Curative on healthy: no mistake should be recorded")


# Scenario: Fungicide reduces transmission and speeds recovery
func _scenario_fungicide_reduces_transmission() -> void:
	var s: Dictionary = _make_setup()
	var tc: TreatmentController = s["tc"]
	var grid: FieldGridState = s["grid"]
	_infect(grid, Vector2i(2, 2), SimulationEnums.DiseaseId.RICE_BLAST)
	tc.commit_treatment(_make_action(SimulationEnums.FieldActionKind.APPLY_FUNGICIDE, Vector2i(2, 2)), grid, 0)
	var mods: TreatmentModifiers = TreatmentResolver.resolve(Vector2i(2, 2), tc.treatment_state, tc.treatment_config)
	_haz_check(mods.hazard_mult, 0.5, "Fungicide reduces transmission: hazard *= 0.5")
	_haz_check(mods.gamma_scale, 1.0 / 0.7, "Fungicide speeds recovery: gamma ~1.43")


# Scenario: Fungicide lasts 3 turns
func _scenario_fungicide_lasts_3_turns() -> void:
	var s: Dictionary = _make_setup()
	var tc: TreatmentController = s["tc"]
	var grid: FieldGridState = s["grid"]
	_infect(grid, Vector2i(2, 2), SimulationEnums.DiseaseId.RICE_BLAST)
	tc.commit_treatment(_make_action(SimulationEnums.FieldActionKind.APPLY_FUNGICIDE, Vector2i(2, 2)), grid, 0)
	# Advance 3 turns
	for i: int in range(3):
		tc.advance_turn(i + 1)
	if tc.treatment_state.get_effect(Vector2i(2, 2), &"fungicide") != null:
		fail("Fungicide lasts 3: effect should expire after 3 turns")
	# Check expiry event
	var has_expiry: bool = false
	for ev: Dictionary in tc.treatment_state.events:
		if ev.get("type", "") == "expired":
			has_expiry = true
	if not has_expiry:
		fail("Fungicide lasts 3: expiry cue should be emitted")


# Scenario: Bactericide treats bacterial disease
func _scenario_bactericide_treats_bacterial() -> void:
	var s: Dictionary = _make_setup()
	var tc: TreatmentController = s["tc"]
	var grid: FieldGridState = s["grid"]
	_infect(grid, Vector2i(2, 2), SimulationEnums.DiseaseId.BACTERIAL_LEAF_BLIGHT)
	tc.commit_treatment(_make_action(SimulationEnums.FieldActionKind.APPLY_BACTERICIDE, Vector2i(2, 2)), grid, 0)
	if tc.treatment_state.get_effect(Vector2i(2, 2), &"bactericide") == null:
		fail("Bactericide: effect should be active")


# Scenario: Protectant fungicide lowers susceptibility
func _scenario_protectant_lowers_susceptibility() -> void:
	var s: Dictionary = _make_setup()
	var tc: TreatmentController = s["tc"]
	var grid: FieldGridState = s["grid"]
	tc.commit_treatment(_make_action(SimulationEnums.FieldActionKind.APPLY_PROTECTANT, Vector2i(2, 2)), grid, 0)
	var mods: TreatmentModifiers = TreatmentResolver.resolve(Vector2i(2, 2), tc.treatment_state, tc.treatment_config)
	_haz_check(mods.hazard_mult, 0.6, "Protectant: hazard *= 0.6")
	_haz_check(mods.gamma_scale, 1.0, "Protectant: recovery unchanged")


# Scenario: Protectant wears off
func _scenario_protectant_wears_off() -> void:
	var s: Dictionary = _make_setup()
	var tc: TreatmentController = s["tc"]
	var grid: FieldGridState = s["grid"]
	tc.commit_treatment(_make_action(SimulationEnums.FieldActionKind.APPLY_PROTECTANT, Vector2i(2, 2)), grid, 0)
	for i: int in range(4):
		tc.advance_turn(i + 1)
	if tc.treatment_state.get_effect(Vector2i(2, 2), &"protectant") != null:
		fail("Protectant wears off: should expire after 4 turns")
	var mods: TreatmentModifiers = TreatmentResolver.resolve(Vector2i(2, 2), tc.treatment_state, tc.treatment_config)
	_haz_check(mods.hazard_mult, 1.0, "Protectant wears off: hazard returns to 1.0")


# Scenario: Enhancer raises resilience without curing
func _scenario_enhancer_raises_resilience() -> void:
	var s: Dictionary = _make_setup()
	var tc: TreatmentController = s["tc"]
	var grid: FieldGridState = s["grid"]
	_infect(grid, Vector2i(2, 2), SimulationEnums.DiseaseId.RICE_TUNGRO)
	var before: float = grid.get_cell(Vector2i(2, 2)).infected_fraction
	tc.commit_treatment(_make_action(SimulationEnums.FieldActionKind.APPLY_ENHANCER, Vector2i(2, 2)), grid, 0)
	var mods: TreatmentModifiers = TreatmentResolver.resolve(Vector2i(2, 2), tc.treatment_state, tc.treatment_config)
	_haz_check(mods.hazard_mult, 0.85, "Enhancer: hazard *= 0.85")
	_haz_check(mods.gamma_scale, 1.0, "Enhancer: recovery unchanged")
	if grid.get_cell(Vector2i(2, 2)).infected_fraction != before:
		fail("Enhancer: infection status must be unchanged")


# Scenario: Repeated enhancer has diminishing returns
func _scenario_repeated_enhancer_diminishing() -> void:
	var s: Dictionary = _make_setup()
	var tc: TreatmentController = s["tc"]
	var grid: FieldGridState = s["grid"]
	var target: Vector2i = Vector2i(2, 2)
	tc.commit_treatment(_make_action(SimulationEnums.FieldActionKind.APPLY_ENHANCER, target), grid, 0)
	var p1: float = tc.treatment_state.get_effect(target, &"enhancer").potency
	tc.treatment_state.set_cooldown(&"enhancer", 0)
	tc.commit_treatment(_make_action(SimulationEnums.FieldActionKind.APPLY_ENHANCER, target), grid, 0)
	var p2: float = tc.treatment_state.get_effect(target, &"enhancer").potency
	_haz_check(p2 / p1, 0.7, "Repeated enhancer: potency ratio should be 0.7")


# Scenario: Same treatment does not stack
func _scenario_same_treatment_no_stack() -> void:
	var s: Dictionary = _make_setup()
	var tc: TreatmentController = s["tc"]
	var grid: FieldGridState = s["grid"]
	_infect(grid, Vector2i(2, 2), SimulationEnums.DiseaseId.RICE_BLAST)
	tc.commit_treatment(_make_action(SimulationEnums.FieldActionKind.APPLY_FUNGICIDE, Vector2i(2, 2)), grid, 0)
	var p1: float = tc.treatment_state.get_effect(Vector2i(2, 2), &"fungicide").potency
	# Advance 1 turn (effect has 2 remaining)
	tc.advance_turn(1)
	tc.treatment_state.set_cooldown(&"fungicide", 0)
	# Second application: refreshes duration, keeps max potency
	tc.commit_treatment(_make_action(SimulationEnums.FieldActionKind.APPLY_FUNGICIDE, Vector2i(2, 2)), grid, 1)
	var e: TreatmentEffect = tc.treatment_state.get_effect(Vector2i(2, 2), &"fungicide")
	if e.remaining_turns != 3:
		fail("No stack: remaining turns should be refreshed to 3, got %d" % e.remaining_turns)
	if e.potency != p1:
		fail("No stack: potency should be unchanged (max)")


# Scenario: Different treatments combine
func _scenario_different_treatments_combine() -> void:
	var s: Dictionary = _make_setup()
	var tc: TreatmentController = s["tc"]
	var grid: FieldGridState = s["grid"]
	_infect(grid, Vector2i(2, 2), SimulationEnums.DiseaseId.RICE_BLAST)
	tc.commit_treatment(_make_action(SimulationEnums.FieldActionKind.APPLY_FUNGICIDE, Vector2i(2, 2)), grid, 0)
	tc.treatment_state.set_cooldown(&"enhancer", 0)
	tc.commit_treatment(_make_action(SimulationEnums.FieldActionKind.APPLY_ENHANCER, Vector2i(2, 2)), grid, 0)
	var mods: TreatmentModifiers = TreatmentResolver.resolve(Vector2i(2, 2), tc.treatment_state, tc.treatment_config)
	# 0.5 (fungicide) * 0.85 (enhancer) = 0.425
	_haz_check(mods.hazard_mult, 0.425, "Combine: hazard = product of both effects")


# Scenario: Overusing fungicide weakens it
func _scenario_overusing_fungicide_weakens() -> void:
	var s: Dictionary = _make_setup()
	var tc: TreatmentController = s["tc"]
	var grid: FieldGridState = s["grid"]
	_infect(grid, Vector2i(0, 0), SimulationEnums.DiseaseId.RICE_BLAST)
	# Use past threshold (threshold=2)
	for i: int in range(4):
		tc.treatment_state.set_cooldown(&"fungicide", 0)
		tc.commit_treatment(_make_action(SimulationEnums.FieldActionKind.APPLY_FUNGICIDE, Vector2i(0, 0)), grid, i)
	var e: TreatmentEffect = tc.treatment_state.get_effect(Vector2i(0, 0), &"fungicide")
	if e == null:
		fail("Overuse: effect should exist")
	elif e.potency >= 1.0:
		fail("Overuse: potency should be reduced, got %f" % e.potency)
	# Resistance indicator should be raised (potency < 1.0)
	var potency: float = tc.get_resistance_potency(TreatmentData.ResistanceGroup.FUNGICIDE, 3)
	if potency >= 1.0:
		fail("Overuse: resistance indicator should be raised")


# Scenario: Protectant counts toward fungicide resistance
func _scenario_protectant_counts_toward_resistance() -> void:
	var s: Dictionary = _make_setup()
	var tc: TreatmentController = s["tc"]
	var grid: FieldGridState = s["grid"]
	# Use fungicide twice (at threshold)
	_infect(grid, Vector2i(0, 0), SimulationEnums.DiseaseId.RICE_BLAST)
	for i: int in range(2):
		tc.treatment_state.set_cooldown(&"fungicide", 0)
		tc.commit_treatment(_make_action(SimulationEnums.FieldActionKind.APPLY_FUNGICIDE, Vector2i(0, 0)), grid, i)
	var before: int = tc.treatment_state.usage_count(TreatmentData.ResistanceGroup.FUNGICIDE, 10, 1)
	# Apply protectant (same group)
	tc.treatment_state.set_cooldown(&"protectant", 0)
	tc.commit_treatment(_make_action(SimulationEnums.FieldActionKind.APPLY_PROTECTANT, Vector2i(1, 1)), grid, 1)
	var after: int = tc.treatment_state.usage_count(TreatmentData.ResistanceGroup.FUNGICIDE, 10, 1)
	if after <= before:
		fail("Protectant resistance: usage count should increase, %d -> %d" % [before, after])


# Scenario: Resistance decays when unused
func _scenario_resistance_decays() -> void:
	var s: Dictionary = _make_setup()
	var tc: TreatmentController = s["tc"]
	var grid: FieldGridState = s["grid"]
	_infect(grid, Vector2i(0, 0), SimulationEnums.DiseaseId.RICE_BLAST)
	# Build up resistance
	for i: int in range(4):
		tc.treatment_state.set_cooldown(&"fungicide", 0)
		tc.commit_treatment(_make_action(SimulationEnums.FieldActionKind.APPLY_FUNGICIDE, Vector2i(0, 0)), grid, i)
	# Advance enough turns for usage to expire (window=10)
	for i: int in range(11):
		tc.advance_turn(4 + i + 1)
	var potency: float = tc.get_resistance_potency(TreatmentData.ResistanceGroup.FUNGICIDE, 15)
	if potency < 1.0 - 0.001:
		fail("Resistance decay: should return to 1.0, got %f" % potency)


# Scenario: Treatment state survives save and load
func _scenario_save_and_load() -> void:
	var state: TreatmentState = TreatmentState.new()
	var e: TreatmentEffect = TreatmentEffect.new()
	e.treatment_id = &"fungicide"
	e.cell = Vector2i(1, 2)
	e.remaining_turns = 2
	e.potency = 0.8
	state.put_effect(e)
	state.set_cooldown(&"fungicide", 1)
	state.log_usage(TreatmentData.ResistanceGroup.FUNGICIDE, 0)
	state.log_mistake(&"fungicide", 5, Vector2i(1, 2), 0)
	var saved: Dictionary = state.to_dict()
	var loaded: TreatmentState = TreatmentState.from_dict(saved)
	if loaded.get_effect(Vector2i(1, 2), &"fungicide") == null:
		fail("Save/load: effect should be restored")
	if loaded.get_cooldown(&"fungicide") != 1:
		fail("Save/load: cooldown should be restored")
	if loaded.usage_count(TreatmentData.ResistanceGroup.FUNGICIDE, 10, 0) != 1:
		fail("Save/load: usage should be restored")
	if loaded.mistakes.size() != 1:
		fail("Save/load: mistakes should be restored")


# Scenario: Older save loads with no treatment state
func _scenario_older_save_loads_empty() -> void:
	var loaded: TreatmentState = TreatmentState.from_dict({})
	if loaded.effects.size() != 0:
		fail("Old save: effects should be empty")
	if loaded.cooldowns.size() != 0:
		fail("Old save: cooldowns should be empty")
	if loaded.mistakes.size() != 0:
		fail("Old save: mistakes should be empty")


func _haz_check(a: float, b: float, label: String) -> void:
	if absf(a - b) > 0.01:
		failures += 1
		printerr("FAIL: %s: expected %f, got %f" % [label, b, a])


func fail(message: String) -> void:
	failures += 1
	printerr("FAIL: " + message)
