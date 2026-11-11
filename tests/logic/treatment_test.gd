extends SceneTree
## Comprehensive treatment system unit tests.
## Covers Tasks 2-13: disease categories, treatment data, state save/load,
## resolver math, process_turn integration, enum preservation, controller
## commit logic, treatment behaviors, resistance, and turn advance.

var failures: int = 0


func _initialize() -> void:
	_test_disease_categories()
	_test_disease_categories_unset_fails()
	_test_treatment_data_validation()
	_test_treatment_config_load()
	_test_treatment_state_roundtrip()
	_test_treatment_state_old_save()
	_test_resolver_overlap()
	_test_resolver_clamps()
	_test_resolver_gamma_scale()
	_test_enum_preservation()
	_test_controller_happy_path()
	_test_controller_mismatch()
	_test_controller_mixed_area()
	_test_controller_healthy_noop()
	_test_controller_discard()
	_test_no_apply_outside_commit()
	_test_fungicide_behavior()
	_test_bactericide_behavior()
	_test_protectant_behavior()
	_test_protectant_infected_mismatch()
	_test_enhancer_behavior()
	_test_enhancer_neutrality()
	_test_enhancer_diminishing_returns()
	_test_resistance_monotonic()
	_test_resistance_shared_group()
	_test_resistance_insecticide_excluded()
	_test_resistance_decay()
	_test_turn_advance_expiry()
	_test_turn_advance_cooldown()
	_test_turn_advance_decay()
	_test_determinism()
	if failures == 0:
		print("TREATMENT_PASS")
	quit(0 if failures == 0 else 1)


# --- Task 2.4: Disease category unit tests ---

func _test_disease_categories() -> void:
	var catalog: DiseaseDatabase = load("res://src/data/databases/default_disease_database.tres") as DiseaseDatabase
	if catalog == null:
		fail("Disease database must load")
		return
	# Every resource must have a non-UNSET category (validation passes)
	for disease: DiseaseData in catalog.diseases:
		if disease == null:
			continue
		if not disease.validate().is_empty():
			fail("Disease %s must validate cleanly" % disease.display_name)
	# Specific mappings
	_check_category(catalog, SimulationEnums.DiseaseId.RICE_BLAST, DiseaseData.DiseaseCategory.FUNGAL, false, "Rice Blast")
	_check_category(catalog, SimulationEnums.DiseaseId.BACTERIAL_LEAF_BLIGHT, DiseaseData.DiseaseCategory.BACTERIAL, false, "BLB")
	_check_category(catalog, SimulationEnums.DiseaseId.RICE_TUNGRO, DiseaseData.DiseaseCategory.VIRAL, true, "Tungro")
	_check_category(catalog, SimulationEnums.DiseaseId.SUGARCANE_SMUT, DiseaseData.DiseaseCategory.FUNGAL, false, "Smuts")
	_check_category(catalog, SimulationEnums.DiseaseId.LEAF_SCALD, DiseaseData.DiseaseCategory.BACTERIAL, false, "Scald")
	_check_category(catalog, SimulationEnums.DiseaseId.COMMON_CORN_RUST, DiseaseData.DiseaseCategory.FUNGAL, false, "Rust")
	_check_category(catalog, SimulationEnums.DiseaseId.PHILIPPINE_DOWNY_MILDEW, DiseaseData.DiseaseCategory.FUNGAL, false, "Mildew")
	_check_category(catalog, SimulationEnums.DiseaseId.EAR_ROT, DiseaseData.DiseaseCategory.FUNGAL, false, "Ear Rot")
	_check_category(catalog, SimulationEnums.DiseaseId.RSSI, DiseaseData.DiseaseCategory.VIRAL, true, "RSSI")


func _check_category(catalog: DiseaseDatabase, id: int, expected_cat: int, expected_vec: bool, label: String) -> void:
	var d: DiseaseData = catalog.get_disease(id)
	if d == null:
		fail("Missing disease for %s" % label)
		return
	if d.disease_category != expected_cat:
		fail("%s category mismatch: got %d expected %d" % [label, d.disease_category, expected_cat])
	if d.is_vector_borne != expected_vec:
		fail("%s vector-borne mismatch: got %s expected %s" % [label, d.is_vector_borne, expected_vec])


func _test_disease_categories_unset_fails() -> void:
	var d: DiseaseData = DiseaseData.new()
	d.display_name = "Test"
	d.disease_category = DiseaseData.DiseaseCategory.UNSET
	# Code-created instances (no resource_path) are allowed to be UNSET
	if not d.validate().is_empty():
		# If validation fails for other reasons, that's fine
		# but it should NOT fail specifically for UNSET without a resource_path
		var errors: PackedStringArray = d.validate()
		var has_unset_error: bool = false
		for e: String in errors:
			if e.contains("disease_category"):
				has_unset_error = true
		if has_unset_error:
			fail("Code-created UNSET should not fail validation without resource_path")
	# Saved resources with UNSET must fail
	d.resource_path = "res://test/disease.tres"
	var saved_errors: PackedStringArray = d.validate()
	var saved_has_unset: bool = false
	for e: String in saved_errors:
		if e.contains("disease_category"):
			saved_has_unset = true
	if not saved_has_unset:
		fail("Saved resource with UNSET disease_category must fail validation")


# --- Task 3.3: Treatment data validation ---

func _test_treatment_data_validation() -> void:
	var config: TreatmentConfig = load("res://src/data/treatments/treatment_config.tres") as TreatmentConfig
	if config == null:
		fail("Treatment config must load")
		return
	var errors: PackedStringArray = config.validate()
	if not errors.is_empty():
		for e: String in errors:
			fail("Config validation: %s" % e)
	# Check all 5 treatments loaded
	if config.treatments.size() != 5:
		fail("Config must have 5 treatments, got %d" % config.treatments.size())
	# Check specific treatment defaults
	var fung: TreatmentData = config.get_data(&"fungicide")
	if fung == null:
		fail("Fungicide must be in config")
	else:
		check_approx(fung.hazard_mult, 0.5, "Fungicide hazard_mult")
		check_approx(fung.recovery_period_mult, 0.7, "Fungicide recovery_period_mult")
		if fung.duration_turns != 3:
			fail("Fungicide duration should be 3, got %d" % fung.duration_turns)
		if fung.applies_to != TreatmentData.AppliesTo.INFECTED:
			fail("Fungicide applies_to should be INFECTED")
		if fung.resistance_group != TreatmentData.ResistanceGroup.FUNGICIDE:
			fail("Fungicide resistance_group should be FUNGICIDE")
	var prot: TreatmentData = config.get_data(&"protectant")
	if prot == null:
		fail("Protectant must be in config")
	else:
		check_approx(prot.susceptibility_mult, 0.6, "Protectant susceptibility_mult")
		if prot.duration_turns != 4:
			fail("Protectant duration should be 4, got %d" % prot.duration_turns)
		if prot.resistance_group != TreatmentData.ResistanceGroup.FUNGICIDE:
			fail("Protectant resistance should be FUNGICIDE (shared)")
	var enh: TreatmentData = config.get_data(&"enhancer")
	if enh == null:
		fail("Enhancer must be in config")
	else:
		check_approx(enh.resilience_bonus, 0.15, "Enhancer resilience_bonus")
		check_approx(enh.vitality_loss_mult, 0.7, "Enhancer vitality_loss_mult")
		if enh.target_mode != TreatmentData.TargetMode.CELL_OR_AREA:
			fail("Enhancer target_mode should be CELL_OR_AREA")


# --- Task 3.3: Treatment config loads from .tres ---

func _test_treatment_config_load() -> void:
	var config: TreatmentConfig = load("res://src/data/treatments/treatment_config.tres") as TreatmentConfig
	if config == null:
		fail("treatment_config.tres must load")
		return
	for t: TreatmentData in config.treatments:
		if t == null:
			fail("Treatment entry must not be null")
			continue
		if t.treatment_id == &"":
			fail("Treatment treatment_id must not be empty")
		if t.display_name.strip_edges().is_empty():
			fail("Treatment display_name must not be blank: %s" % String(t.treatment_id))


# --- Task 4.4: Round-trip save/load test ---

func _test_treatment_state_roundtrip() -> void:
	var state: TreatmentState = TreatmentState.new()
	var config: TreatmentConfig = load("res://src/data/treatments/treatment_config.tres") as TreatmentConfig
	# Add an effect
	var effect: TreatmentEffect = TreatmentEffect.new()
	effect.treatment_id = &"fungicide"
	effect.cell = Vector2i(2, 3)
	effect.remaining_turns = 3
	effect.potency = 0.85
	effect.applied_turn = 5
	state.put_effect(effect)
	state.set_cooldown(&"fungicide", 2)
	state.log_usage(TreatmentData.ResistanceGroup.FUNGICIDE, 5)
	state.log_mistake(&"fungicide", 3, Vector2i(1, 1), 5)
	# Round-trip
	var data: Dictionary = state.to_dict()
	var restored: TreatmentState = TreatmentState.from_dict(data)
	# Verify effects
	var restored_effect: TreatmentEffect = restored.get_effect(Vector2i(2, 3), &"fungicide")
	if restored_effect == null:
		fail("Round-trip: effect must be restored")
	else:
		if restored_effect.remaining_turns != 3:
			fail("Round-trip: remaining_turns mismatch")
		check_approx(restored_effect.potency, 0.85, "Round-trip potency")
	# Verify cooldowns
	if restored.get_cooldown(&"fungicide") != 2:
		fail("Round-trip: cooldown mismatch, got %d" % restored.get_cooldown(&"fungicide"))
	# Verify usage log
	if restored.usage_count(TreatmentData.ResistanceGroup.FUNGICIDE, 10, 5) != 1:
		fail("Round-trip: usage log mismatch")
	# Verify mistakes
	if restored.mistakes.size() != 1:
		fail("Round-trip: mistakes mismatch, got %d" % restored.mistakes.size())


# --- Task 4.4: Old save loads with empty treatment state ---

func _test_treatment_state_old_save() -> void:
	# Empty dict = old save before treatments existed
	var state: TreatmentState = TreatmentState.from_dict({})
	if state.effects.size() != 0:
		fail("Old save: effects should be empty")
	if state.cooldowns.size() != 0:
		fail("Old save: cooldowns should be empty")
	if state.usage_log.size() != 0:
		fail("Old save: usage_log should be empty")
	if state.enhancer_uses.size() != 0:
		fail("Old save: enhancer_uses should be empty")
	if state.mistakes.size() != 0:
		fail("Old save: mistakes should be empty")
	# Missing keys dict
	var partial: Dictionary = {"cooldowns": {"fungicide": 1}}
	var state2: TreatmentState = TreatmentState.from_dict(partial)
	if state2.get_cooldown(&"fungicide") != 1:
		fail("Partial save: cooldown should load")
	if state2.effects.size() != 0:
		fail("Partial save: missing effects should be empty")


# --- Task 5.4: Resolver overlap and clamp tests ---

func _test_resolver_overlap() -> void:
	var state: TreatmentState = TreatmentState.new()
	var config: TreatmentConfig = load("res://src/data/treatments/treatment_config.tres") as TreatmentConfig
	var cell: Vector2i = Vector2i(0, 0)
	# Fungicide + enhancer on same cell → multiplicative
	var fung: TreatmentData = config.get_data(&"fungicide")
	var enh: TreatmentData = config.get_data(&"enhancer")
	var e1: TreatmentEffect = TreatmentEffect.new()
	e1.treatment_id = &"fungicide"
	e1.cell = cell
	e1.remaining_turns = 3
	e1.potency = 1.0
	state.put_effect(e1)
	var e2: TreatmentEffect = TreatmentEffect.new()
	e2.treatment_id = &"enhancer"
	e2.cell = cell
	e2.remaining_turns = 5
	e2.potency = 1.0
	state.put_effect(e2)
	var mods: TreatmentModifiers = TreatmentResolver.resolve(cell, state, config)
	# fungicide: hazard *= 0.5, enhancer: hazard *= (1 - 0.15) = 0.85
	# product = 0.5 * 0.85 = 0.425
	check_approx(mods.hazard_mult, 0.425, "Overlap hazard product")


func _test_resolver_clamps() -> void:
	var state: TreatmentState = TreatmentState.new()
	var config: TreatmentConfig = load("res://src/data/treatments/treatment_config.tres") as TreatmentConfig
	# No effects → identity
	var mods: TreatmentModifiers = TreatmentResolver.resolve(Vector2i(0, 0), state, config)
	check_approx(mods.hazard_mult, 1.0, "No effects hazard")
	check_approx(mods.gamma_scale, 1.0, "No effects gamma")
	# Multiple fungicides on same cell don't stack (put_effect merges)
	var e1: TreatmentEffect = TreatmentEffect.new()
	e1.treatment_id = &"fungicide"
	e1.cell = Vector2i(0, 0)
	e1.remaining_turns = 3
	e1.potency = 1.0
	state.put_effect(e1)
	var e2: TreatmentEffect = TreatmentEffect.new()
	e2.treatment_id = &"fungicide"
	e2.cell = Vector2i(0, 0)
	e2.remaining_turns = 3
	e2.potency = 1.0
	state.put_effect(e2)
	# Should only have one fungicide effect (merged)
	var effects: Array[TreatmentEffect] = state.effects_on(Vector2i(0, 0))
	if effects.size() != 1:
		fail("Same treatment should merge, got %d effects" % effects.size())


func _test_resolver_gamma_scale() -> void:
	var state: TreatmentState = TreatmentState.new()
	var config: TreatmentConfig = load("res://src/data/treatments/treatment_config.tres") as TreatmentConfig
	var e: TreatmentEffect = TreatmentEffect.new()
	e.treatment_id = &"fungicide"
	e.cell = Vector2i(0, 0)
	e.remaining_turns = 3
	e.potency = 1.0
	state.put_effect(e)
	var mods: TreatmentModifiers = TreatmentResolver.resolve(Vector2i(0, 0), state, config)
	# gamma_scale = 1 / 0.7 ≈ 1.4286
	check_approx(mods.gamma_scale, 1.0 / 0.7, "Gamma scale = 1/recovery_period_mult")


# --- Task 7.3: Enum value preservation ---

func _test_enum_preservation() -> void:
	# Existing values must be unchanged
	if SimulationEnums.FieldActionKind.REMOVE_CROP != 0:
		fail("REMOVE_CROP must be 0")
	if SimulationEnums.FieldActionKind.DIG_GRASS != 1:
		fail("DIG_GRASS must be 1")
	if SimulationEnums.FieldActionKind.MAKE_PADDY != 2:
		fail("MAKE_PADDY must be 2")
	if SimulationEnums.FieldActionKind.PLANT != 3:
		fail("PLANT must be 3")
	if SimulationEnums.FieldActionKind.MOVE_CROP != 4:
		fail("MOVE_CROP must be 4")
	if SimulationEnums.FieldActionKind.HARVEST != 5:
		fail("HARVEST must be 5")
	if SimulationEnums.FieldActionKind.WATER_SOIL != 6:
		fail("WATER_SOIL must be 6")
	if SimulationEnums.FieldActionKind.FERTILIZE != 7:
		fail("FERTILIZE must be 7")
	# New treatment values
	if SimulationEnums.FieldActionKind.APPLY_FUNGICIDE != 8:
		fail("APPLY_FUNGICIDE must be 8")
	if SimulationEnums.FieldActionKind.APPLY_BACTERICIDE != 9:
		fail("APPLY_BACTERICIDE must be 9")
	if SimulationEnums.FieldActionKind.APPLY_PROTECTANT != 10:
		fail("APPLY_PROTECTANT must be 10")
	if SimulationEnums.FieldActionKind.APPLY_ENHANCER != 11:
		fail("APPLY_ENHANCER must be 11")
	if SimulationEnums.FieldActionKind.APPLY_INSECTICIDE != 12:
		fail("APPLY_INSECTICIDE must be 12")


# --- Task 8.6: Controller commit tests ---

func _make_controller() -> TreatmentController:
	var tc: TreatmentController = TreatmentController.new()
	tc.treatment_config = load("res://src/data/treatments/treatment_config.tres") as TreatmentConfig
	tc.disease_database = load("res://src/data/databases/default_disease_database.tres") as DiseaseDatabase
	tc.treatment_state = TreatmentState.new()
	return tc


func _make_grid() -> FieldGridState:
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
	return grid


func _infect_cell(grid: FieldGridState, coords: Vector2i, disease_id: int) -> void:
	var cell: FieldCellState = grid.get_cell(coords)
	cell.has_active_disease = true
	cell.active_disease_id = disease_id as SimulationEnums.DiseaseId
	cell.sir_state = SimulationEnums.SIRState.I
	cell.infected_fraction = 0.2
	cell.susceptible_fraction = 0.8


func _test_controller_happy_path() -> void:
	var tc: TreatmentController = _make_controller()
	var grid: FieldGridState = _make_grid()
	_infect_cell(grid, Vector2i(2, 2), SimulationEnums.DiseaseId.RICE_BLAST)
	var action: FieldAction = FieldAction.new()
	action.kind = SimulationEnums.FieldActionKind.APPLY_FUNGICIDE
	action.target = Vector2i(2, 2)
	if not tc.commit_treatment(action, grid, 0):
		fail("Happy path: commit should succeed, got: %s" % tc.last_error)
	# Effect should be on the infected cell
	var effect: TreatmentEffect = tc.treatment_state.get_effect(Vector2i(2, 2), &"fungicide")
	if effect == null:
		fail("Happy path: effect should be on target cell")
	else:
		if effect.remaining_turns != 3:
			fail("Happy path: duration should be 3, got %d" % effect.remaining_turns)
	# Cooldown should be started
	if tc.treatment_state.get_cooldown(&"fungicide") != 2:
		fail("Happy path: cooldown should be 2, got %d" % tc.treatment_state.get_cooldown(&"fungicide"))
	# Usage should be logged
	if tc.treatment_state.usage_count(TreatmentData.ResistanceGroup.FUNGICIDE, 10, 0) != 1:
		fail("Happy path: usage should be logged")


func _test_controller_mismatch() -> void:
	var tc: TreatmentController = _make_controller()
	var grid: FieldGridState = _make_grid()
	_infect_cell(grid, Vector2i(2, 2), SimulationEnums.DiseaseId.BACTERIAL_LEAF_BLIGHT)
	var action: FieldAction = FieldAction.new()
	action.kind = SimulationEnums.FieldActionKind.APPLY_FUNGICIDE
	action.target = Vector2i(2, 2)
	tc.commit_treatment(action, grid, 0)
	# No effect on mismatched cell
	if tc.treatment_state.get_effect(Vector2i(2, 2), &"fungicide") != null:
		fail("Mismatch: no effect should be applied")
	# Mistake should be logged
	if tc.treatment_state.mistakes.size() != 1:
		fail("Mismatch: one mistake should be logged, got %d" % tc.treatment_state.mistakes.size())
	# Cost still spent (cooldown started)
	if tc.treatment_state.get_cooldown(&"fungicide") != 2:
		fail("Mismatch: cooldown should still start")


func _test_controller_mixed_area() -> void:
	var tc: TreatmentController = _make_controller()
	var grid: FieldGridState = _make_grid()
	_infect_cell(grid, Vector2i(1, 1), SimulationEnums.DiseaseId.RICE_BLAST)
	_infect_cell(grid, Vector2i(1, 2), SimulationEnums.DiseaseId.BACTERIAL_LEAF_BLIGHT)
	var action: FieldAction = FieldAction.new()
	action.kind = SimulationEnums.FieldActionKind.APPLY_FUNGICIDE
	action.target = Vector2i(1, 1)
	tc.commit_treatment(action, grid, 0)
	# Fungal cell gets effect
	if tc.treatment_state.get_effect(Vector2i(1, 1), &"fungicide") == null:
		fail("Mixed area: fungal cell should have effect")
	# Bacterial cell does NOT get effect (may be outside area_radius=1 from (1,1))
	# (1,2) is within 3x3 of (1,1), so it should be checked
	if tc.treatment_state.get_effect(Vector2i(1, 2), &"fungicide") != null:
		fail("Mixed area: bacterial cell should NOT have effect")
	# At least one mistake logged for the bacterial cell
	if tc.treatment_state.mistakes.size() < 1:
		fail("Mixed area: at least one mistake should be logged")


func _test_controller_healthy_noop() -> void:
	var tc: TreatmentController = _make_controller()
	var grid: FieldGridState = _make_grid()
	# All cells healthy
	var action: FieldAction = FieldAction.new()
	action.kind = SimulationEnums.FieldActionKind.APPLY_FUNGICIDE
	action.target = Vector2i(2, 2)
	tc.commit_treatment(action, grid, 0)
	# No effects, no mistakes
	var has_effect: bool = false
	for y: int in range(5):
		for x: int in range(5):
			if tc.treatment_state.get_effect(Vector2i(x, y), &"fungicide") != null:
				has_effect = true
	if has_effect:
		fail("Healthy noop: no effects should be applied")
	if tc.treatment_state.mistakes.size() != 0:
		fail("Healthy noop: no mistakes should be logged, got %d" % tc.treatment_state.mistakes.size())


func _test_controller_discard() -> void:
	var tc: TreatmentController = _make_controller()
	var grid: FieldGridState = _make_grid()
	# Put on cooldown
	tc.treatment_state.set_cooldown(&"fungicide", 3)
	var action: FieldAction = FieldAction.new()
	action.kind = SimulationEnums.FieldActionKind.APPLY_FUNGICIDE
	action.target = Vector2i(2, 2)
	_infect_cell(grid, Vector2i(2, 2), SimulationEnums.DiseaseId.RICE_BLAST)
	# Commit should fail (re-validation: cooldown)
	if tc.commit_treatment(action, grid, 0):
		fail("Discard: commit should fail on cooldown")
	# No effect should be applied
	if tc.treatment_state.get_effect(Vector2i(2, 2), &"fungicide") != null:
		fail("Discard: no effect should be applied on failed commit")


func _test_no_apply_outside_commit() -> void:
	var tc: TreatmentController = _make_controller()
	var grid: FieldGridState = _make_grid()
	_infect_cell(grid, Vector2i(2, 2), SimulationEnums.DiseaseId.RICE_BLAST)
	# Just preview, don't commit
	var previews: Array = tc.preview(&"fungicide", Vector2i(2, 2), grid)
	# No effects should exist
	if tc.treatment_state.effects.size() != 0:
		fail("No apply outside commit: preview should not create effects")
	# Preview should show MATCH for the infected cell
	var found_match: bool = false
	for p in previews:
		if p.cell == Vector2i(2, 2) and p.classification == TreatmentController.Classification.MATCH:
			found_match = true
	if not found_match:
		fail("No apply outside commit: preview should show MATCH for infected cell")


# --- Task 9: Fungicide and Bactericide behavior ---

func _test_fungicide_behavior() -> void:
	var tc: TreatmentController = _make_controller()
	var grid: FieldGridState = _make_grid()
	_infect_cell(grid, Vector2i(2, 2), SimulationEnums.DiseaseId.RICE_BLAST)
	var action: FieldAction = FieldAction.new()
	action.kind = SimulationEnums.FieldActionKind.APPLY_FUNGICIDE
	action.target = Vector2i(2, 2)
	tc.commit_treatment(action, grid, 0)
	# Verify hazard_mult is 0.5 for the treated cell
	var config: TreatmentConfig = tc.treatment_config
	var mods: TreatmentModifiers = TreatmentResolver.resolve(Vector2i(2, 2), tc.treatment_state, config)
	check_approx(mods.hazard_mult, 0.5, "Fungicide hazard_mult on fungal cell")


func _test_bactericide_behavior() -> void:
	var tc: TreatmentController = _make_controller()
	var grid: FieldGridState = _make_grid()
	_infect_cell(grid, Vector2i(2, 2), SimulationEnums.DiseaseId.BACTERIAL_LEAF_BLIGHT)
	var action: FieldAction = FieldAction.new()
	action.kind = SimulationEnums.FieldActionKind.APPLY_BACTERICIDE
	action.target = Vector2i(2, 2)
	tc.commit_treatment(action, grid, 0)
	var mods: TreatmentModifiers = TreatmentResolver.resolve(Vector2i(2, 2), tc.treatment_state, tc.treatment_config)
	check_approx(mods.hazard_mult, 0.5, "Bactericide hazard_mult on bacterial cell")
	check_approx(mods.gamma_scale, 1.0 / 0.7, "Bactericide gamma_scale")
	# Separate cost, cooldown, resistance group
	if tc.treatment_state.get_cooldown(&"bactericide") != 2:
		fail("Bactericide: separate cooldown")
	if tc.treatment_state.usage_count(TreatmentData.ResistanceGroup.BACTERICIDE, 10, 0) != 1:
		fail("Bactericide: usage logged to BACTERICIDE group")


# --- Task 10: Protectant behavior ---

func _test_protectant_behavior() -> void:
	var tc: TreatmentController = _make_controller()
	var grid: FieldGridState = _make_grid()
	# Healthy cell
	var action: FieldAction = FieldAction.new()
	action.kind = SimulationEnums.FieldActionKind.APPLY_PROTECTANT
	action.target = Vector2i(2, 2)
	tc.commit_treatment(action, grid, 0)
	var mods: TreatmentModifiers = TreatmentResolver.resolve(Vector2i(2, 2), tc.treatment_state, tc.treatment_config)
	# susceptibility_mult = 0.6 → hazard *= 0.6
	check_approx(mods.hazard_mult, 0.6, "Protectant susceptibility hazard")
	# No gamma change
	check_approx(mods.gamma_scale, 1.0, "Protectant no gamma change")


func _test_protectant_infected_mismatch() -> void:
	var tc: TreatmentController = _make_controller()
	var grid: FieldGridState = _make_grid()
	# Infect with bacterial (non-fungal) disease
	_infect_cell(grid, Vector2i(2, 2), SimulationEnums.DiseaseId.BACTERIAL_LEAF_BLIGHT)
	var action: FieldAction = FieldAction.new()
	action.kind = SimulationEnums.FieldActionKind.APPLY_PROTECTANT
	action.target = Vector2i(2, 2)
	tc.commit_treatment(action, grid, 0)
	# No effect on mismatched cell
	if tc.treatment_state.get_effect(Vector2i(2, 2), &"protectant") != null:
		fail("Protectant: no effect on non-fungal infected cell")
	# Mistake logged
	if tc.treatment_state.mistakes.size() < 1:
		fail("Protectant: mismatch should log mistake")


# --- Task 11: Enhancer behavior ---

func _test_enhancer_behavior() -> void:
	var tc: TreatmentController = _make_controller()
	var grid: FieldGridState = _make_grid()
	_infect_cell(grid, Vector2i(2, 2), SimulationEnums.DiseaseId.RICE_TUNGRO)
	var action: FieldAction = FieldAction.new()
	action.kind = SimulationEnums.FieldActionKind.APPLY_ENHANCER
	action.target = Vector2i(2, 2)
	tc.commit_treatment(action, grid, 0)
	var mods: TreatmentModifiers = TreatmentResolver.resolve(Vector2i(2, 2), tc.treatment_state, tc.treatment_config)
	# hazard *= (1 - 0.15) = 0.85
	check_approx(mods.hazard_mult, 0.85, "Enhancer hazard (resilience)")
	# gamma unchanged
	check_approx(mods.gamma_scale, 1.0, "Enhancer gamma unchanged")
	# vitality_loss_mult = 0.7
	check_approx(mods.vitality_loss_mult, 0.7, "Enhancer vitality_loss_mult")


func _test_enhancer_neutrality() -> void:
	var tc: TreatmentController = _make_controller()
	var grid: FieldGridState = _make_grid()
	_infect_cell(grid, Vector2i(2, 2), SimulationEnums.DiseaseId.RICE_TUNGRO)
	var before_infected: float = grid.get_cell(Vector2i(2, 2)).infected_fraction
	var before_active: bool = grid.get_cell(Vector2i(2, 2)).has_active_disease
	var action: FieldAction = FieldAction.new()
	action.kind = SimulationEnums.FieldActionKind.APPLY_ENHANCER
	action.target = Vector2i(2, 2)
	tc.commit_treatment(action, grid, 0)
	# Infection status unchanged (commit doesn't change fractions)
	var cell: FieldCellState = grid.get_cell(Vector2i(2, 2))
	if cell.infected_fraction != before_infected:
		fail("Enhancer neutrality: infection fraction must not change on commit")
	if cell.has_active_disease != before_active:
		fail("Enhancer neutrality: active disease must not change on commit")
	# Gamma scale = 1.0
	var mods: TreatmentModifiers = TreatmentResolver.resolve(Vector2i(2, 2), tc.treatment_state, tc.treatment_config)
	check_approx(mods.gamma_scale, 1.0, "Enhancer neutrality: gamma unchanged")


func _test_enhancer_diminishing_returns() -> void:
	var tc: TreatmentController = _make_controller()
	var grid: FieldGridState = _make_grid()
	var target: Vector2i = Vector2i(2, 2)
	# First enhancer use
	var action: FieldAction = FieldAction.new()
	action.kind = SimulationEnums.FieldActionKind.APPLY_ENHANCER
	action.target = target
	tc.commit_treatment(action, grid, 0)
	var first_potency: float = tc.treatment_state.get_effect(target, &"enhancer").potency
	# Should be 1.0 (0 uses before)
	check_approx(first_potency, 1.0, "First enhancer potency = 1.0")
	# Second use (same window)
	tc.treatment_state.set_cooldown(&"enhancer", 0)  # Clear cooldown for test
	action.target = target
	tc.commit_treatment(action, grid, 0)
	var second_potency: float = tc.treatment_state.get_effect(target, &"enhancer").potency
	# Should be 0.7^1 = 0.7
	check_approx(second_potency, 0.7, "Second enhancer potency = 0.7")


# --- Task 12: Resistance tracking ---

func _test_resistance_monotonic() -> void:
	var tc: TreatmentController = _make_controller()
	var grid: FieldGridState = _make_grid()
	_infect_cell(grid, Vector2i(0, 0), SimulationEnums.DiseaseId.RICE_BLAST)
	var action: FieldAction = FieldAction.new()
	action.kind = SimulationEnums.FieldActionKind.APPLY_FUNGICIDE
	action.target = Vector2i(0, 0)
	var potencies: Array[float] = []
	for i: int in range(5):
		tc.treatment_state.set_cooldown(&"fungicide", 0)  # Clear for test
		tc.commit_treatment(action, grid, i)
		var e: TreatmentEffect = tc.treatment_state.get_effect(Vector2i(0, 0), &"fungicide")
		if e != null:
			potencies.append(e.potency)
	# Potency should be monotonically non-increasing
	for i: int in range(1, potencies.size()):
		if potencies[i] > potencies[i - 1] + 0.0001:
			fail("Resistance: potency should be monotonic, %f > %f at index %d" % [potencies[i], potencies[i-1], i])


func _test_resistance_shared_group() -> void:
	var tc: TreatmentController = _make_controller()
	var grid: FieldGridState = _make_grid()
	_infect_cell(grid, Vector2i(0, 0), SimulationEnums.DiseaseId.RICE_BLAST)
	# Apply fungicide (uses FUNGICIDE group)
	var action: FieldAction = FieldAction.new()
	action.kind = SimulationEnums.FieldActionKind.APPLY_FUNGICIDE
	action.target = Vector2i(0, 0)
	tc.commit_treatment(action, grid, 0)
	# Apply protectant (also FUNGICIDE group)
	tc.treatment_state.set_cooldown(&"protectant", 0)
	action.kind = SimulationEnums.FieldActionKind.APPLY_PROTECTANT
	action.target = Vector2i(1, 1)
	tc.commit_treatment(action, grid, 0)
	# Both should contribute to the same group
	var uses: int = tc.treatment_state.usage_count(TreatmentData.ResistanceGroup.FUNGICIDE, 10, 0)
	if uses != 2:
		fail("Shared group: fungicide + protectant should share FUNGICIDE group, got %d uses" % uses)


func _test_resistance_insecticide_excluded() -> void:
	var tc: TreatmentController = _make_controller()
	var grid: FieldGridState = _make_grid()
	_infect_cell(grid, Vector2i(0, 0), SimulationEnums.DiseaseId.RICE_TUNGRO)
	var action: FieldAction = FieldAction.new()
	action.kind = SimulationEnums.FieldActionKind.APPLY_INSECTICIDE
	action.target = Vector2i(0, 0)
	tc.commit_treatment(action, grid, 0)
	# Insecticide uses NONE group, should not log usage
	for group in tc.treatment_state.usage_log:
		fail("Insecticide: should not log usage to any group")
	# Potency should be 1.0 (no resistance)
	var potency: float = TreatmentResolver.resistance_potency(TreatmentData.ResistanceGroup.NONE, tc.treatment_state, tc.treatment_config, 0)
	check_approx(potency, 1.0, "Insecticide excluded from resistance")


func _test_resistance_decay() -> void:
	var tc: TreatmentController = _make_controller()
	var config: TreatmentConfig = tc.treatment_config
	# Log many uses at turn 0
	for i: int in range(5):
		tc.treatment_state.log_usage(TreatmentData.ResistanceGroup.FUNGICIDE, 0)
	# At turn 0, all 5 within window
	if tc.treatment_state.usage_count(TreatmentData.ResistanceGroup.FUNGICIDE, 10, 0) != 5:
		fail("Resistance decay: should have 5 uses at turn 0")
	# Advance 11 turns → all should be pruned
	tc.treatment_state.advance_turn(11, config.resistance_window_turns)
	# Note: advance_turn prunes entries older than current_turn - window_turns
	# After advancing to turn 11, entries at turn 0 are 11 turns old (> window of 10)
	if tc.treatment_state.usage_count(TreatmentData.ResistanceGroup.FUNGICIDE, 10, 11) != 0:
		fail("Resistance decay: uses should be pruned after window expires")
	# Potency should return to 1.0
	var potency: float = TreatmentResolver.resistance_potency(TreatmentData.ResistanceGroup.FUNGICIDE, tc.treatment_state, config, 11)
	check_approx(potency, 1.0, "Resistance decay: potency returns to 1.0")


# --- Task 13: Turn advance ---

func _test_turn_advance_expiry() -> void:
	var state: TreatmentState = TreatmentState.new()
	var config: TreatmentConfig = load("res://src/data/treatments/treatment_config.tres") as TreatmentConfig
	# Add effect with 3 turns remaining
	var e: TreatmentEffect = TreatmentEffect.new()
	e.treatment_id = &"fungicide"
	e.cell = Vector2i(0, 0)
	e.remaining_turns = 3
	e.potency = 1.0
	state.put_effect(e)
	# Advance 3 turns
	for i: int in range(3):
		state.advance_turn(i + 1, config.resistance_window_turns)
	# Effect should be expired
	if state.get_effect(Vector2i(0, 0), &"fungicide") != null:
		fail("Expiry: effect should be gone after 3 turns")
	# Expiry event should have been emitted
	var has_expiry: bool = false
	for ev: Dictionary in state.events:
		if ev.get("type", "") == "expired":
			has_expiry = true
	if not has_expiry:
		fail("Expiry: expiry event should be emitted")


func _test_turn_advance_cooldown() -> void:
	var state: TreatmentState = TreatmentState.new()
	var config: TreatmentConfig = load("res://src/data/treatments/treatment_config.tres") as TreatmentConfig
	state.set_cooldown(&"fungicide", 2)
	state.advance_turn(1, config.resistance_window_turns)
	if state.get_cooldown(&"fungicide") != 1:
		fail("Cooldown: should be 1 after one turn, got %d" % state.get_cooldown(&"fungicide"))
	state.advance_turn(2, config.resistance_window_turns)
	if state.get_cooldown(&"fungicide") != 0:
		fail("Cooldown: should be 0 after two turns, got %d" % state.get_cooldown(&"fungicide"))
	# Cooldown should be removed entirely
	if state.cooldowns.has("fungicide"):
		fail("Cooldown: should be removed when it reaches 0")


func _test_turn_advance_decay() -> void:
	var state: TreatmentState = TreatmentState.new()
	var config: TreatmentConfig = load("res://src/data/treatments/treatment_config.tres") as TreatmentConfig
	state.log_usage(TreatmentData.ResistanceGroup.FUNGICIDE, 0)
	state.log_usage(TreatmentData.ResistanceGroup.FUNGICIDE, 1)
	# Advance to turn 12 (window=10, so turn 0 and 1 should be pruned)
	state.advance_turn(12, config.resistance_window_turns)
	if state.usage_count(TreatmentData.ResistanceGroup.FUNGICIDE, 10, 12) != 0:
		fail("Decay: old usage should be pruned after window")


func _test_determinism() -> void:
	var config: TreatmentConfig = load("res://src/data/treatments/treatment_config.tres") as TreatmentConfig
	var db: DiseaseDatabase = load("res://src/data/databases/default_disease_database.tres") as DiseaseDatabase
	# Two identical runs should produce identical results
	for algo: int in [0, 1, 2]:
		var grid1: FieldGridState = _make_grid()
		var grid2: FieldGridState = _make_grid()
		_infect_cell(grid1, Vector2i(2, 2), SimulationEnums.DiseaseId.RICE_BLAST)
		_infect_cell(grid2, Vector2i(2, 2), SimulationEnums.DiseaseId.RICE_BLAST)
		# Apply fungicide to both
		var tc1: TreatmentController = _make_controller()
		var tc2: TreatmentController = _make_controller()
		var action: FieldAction = FieldAction.new()
		action.kind = SimulationEnums.FieldActionKind.APPLY_FUNGICIDE
		action.target = Vector2i(2, 2)
		tc1.commit_treatment(action, grid1, 0)
		tc2.commit_treatment(action, grid2, 0)
		# Run turns with same seed
		var sim1: SimulationController = SimulationController.new()
		sim1.rng.seed = 42
		sim1.crop_database = load("res://src/data/databases/crop_database.tres") as CropDatabase
		sim1.treatment_state = tc1.treatment_state
		sim1.treatment_config = config
		var sim2: SimulationController = SimulationController.new()
		sim2.rng.seed = 42
		sim2.crop_database = load("res://src/data/databases/crop_database.tres") as CropDatabase
		sim2.treatment_state = tc2.treatment_state
		sim2.treatment_config = config
		for tick: int in range(3):
			sim1.process_turn(grid1, db)
			sim2.process_turn(grid2, db)
			tc1.advance_turn(tick + 1)
			tc2.advance_turn(tick + 1)
		# Compare cells
		for y: int in range(5):
			for x: int in range(5):
				var c1: FieldCellState = grid1.get_cell(Vector2i(x, y))
				var c2: FieldCellState = grid2.get_cell(Vector2i(x, y))
				if c1.infected_fraction != c2.infected_fraction:
					fail("Determinism: infected_fraction mismatch at (%d,%d) algo %d" % [x, y, algo])
					return
				if c1.susceptible_fraction != c2.susceptible_fraction:
					fail("Determinism: susceptible_fraction mismatch at (%d,%d) algo %d" % [x, y, algo])
					return


# --- Helpers ---

func check_approx(a: float, b: float, label: String) -> void:
	if absf(a - b) > 0.001:
		fail("%s: expected %f, got %f" % [label, b, a])


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func fail(message: String) -> void:
	failures += 1
	printerr("FAIL: " + message)
