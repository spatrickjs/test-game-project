extends SceneTree
## R1–R11, R14 through queued arrival commits and detached snapshots.
const ActivationTest = preload("res://tests/logic/disease_activation_test.gd")
var failures: int = 0

func check(value: bool, label: String) -> void:
	if not value:
		failures += 1
		printerr("FAIL: " + label)

func act(farming: FarmingController, target: Vector2i) -> bool:
	var action: FieldAction = FieldAction.new()
	action.kind = SimulationEnums.FieldActionKind.WATER_SOIL
	action.target = target
	action.additions = Vector3(0.1, 0.0, 0.0)
	if not farming.enqueue_action(action):
		return false
	var queued: FieldAction = farming.get_current_action()
	return farming.arrive_at_action(queued.id, target)

func _initialize() -> void:
	var fixture = ActivationTest.Fixture.new()
	check(fixture.setup(), "setup")
	fixture.turns.reset_clock()
	check(fixture.plant_all(), "plant")
	var farming: FarmingController = fixture.farming
	check(not farming.is_farmer_contaminated(), "starts clean")
	var disease: DiseaseData = fixture.turns.disease_database.diseases[0]
	check(farming.seed_infection(Vector2i.ZERO, disease.disease_id, fixture.turns.disease_database, fixture.turns.simulation_controller), "seed")
	check(act(farming, Vector2i.ZERO), "infected contact commits")
	check(farming.is_farmer_contaminated(), "pickup")
	farming.farmer_transmission_chance = 1.0
	var simulation_state: int = fixture.turns.simulation_controller.rng.state
	check(act(farming, Vector2i(1, 0)), "transmission commits")
	check(farming.get_grid_snapshot().get_cell(Vector2i(1, 0)).has_active_disease, "infection")
	check(fixture.turns.simulation_controller.rng.state == simulation_state, "simulation RNG preserved")
	check(fixture.turns.turn_index == 0, "clock preserved")
	var snapshot: FieldGridState = farming.get_grid_snapshot()
	snapshot.get_cell(Vector2i(1, 0)).has_active_disease = false
	check(farming.get_grid_snapshot().get_cell(Vector2i(1, 0)).has_active_disease, "snapshot detached")
	var rng_state: int = fixture.activation.get_state_snapshot().rng_state
	check(not farming.arrive_at_action(-1, Vector2i(1, 0)), "duplicate rejected")
	check(fixture.activation.get_state_snapshot().rng_state == rng_state, "duplicate preserves RNG")
	farming.farmer_transmission_chance = 0.0
	check(act(farming, Vector2i(2, 0)), "miss commits")
	check(not farming.get_grid_snapshot().get_cell(Vector2i(2, 0)).has_active_disease, "zero chance")
	farming.treatment_controller = TreatmentController.new()
	var protection: TreatmentEffect = TreatmentEffect.new()
	protection.treatment_id = &"protectant"
	protection.cell = Vector2i(3, 0)
	protection.remaining_turns = 2
	farming.treatment_controller.treatment_state.put_effect(protection)
	farming.farmer_transmission_chance = 1.0
	rng_state = fixture.activation.get_state_snapshot().rng_state
	check(act(farming, Vector2i(3, 0)), "protected arrival")
	check(not farming.get_grid_snapshot().get_cell(Vector2i(3, 0)).has_active_disease, "protection blocks")
	check(fixture.activation.get_state_snapshot().rng_state == rng_state, "protection skips roll")
	farming.treatment_controller = null
	var soil_before: float = farming.get_grid_snapshot().get_cell(Vector2i(4, 0)).soil.moisture
	farming.vector_activation = null
	check(not act(farming, Vector2i(4, 0)), "missing dependency rejects staged action")
	check(farming.get_grid_snapshot().get_cell(Vector2i(4, 0)).soil.moisture == soil_before, "rollback soil")
	check(farming.is_farmer_contaminated(), "rollback contamination")
	check(fixture.activation.get_state_snapshot().rng_state == rng_state, "rollback RNG")
	farming.vector_activation = fixture.activation
	for turn: int in range(3):
		check(farming.advance_simulated_turn(fixture.turns.simulation_controller, fixture.turns.disease_database, null, turn), "expiry turn")
		check(farming.is_farmer_contaminated() == (turn < 2), "expiry boundary")
	fixture.dispose()
	if failures == 0:
		print("FARMER_DISEASE_VECTOR_PASS")
	quit(0 if failures == 0 else 1)
