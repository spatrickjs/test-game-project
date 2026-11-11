extends SceneTree
## Infected debris R1-R6; chance and queued-harvest feature scenarios.
const Fixture = preload("res://tests/logic/gameplay_test_fixture.gd")
const InspectorFixture = preload("res://tests/presentation/inspector_test_fixture.gd")
const Kind = SimulationEnums.FieldActionKind
var failures: PackedStringArray = PackedStringArray()

class RejectingFarming extends FarmingController:
	func _validate_harvest_candidate(_candidate: FieldGridState) -> PackedStringArray:
		return PackedStringArray(["Injected post-draw failure"])


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for row: Array in [[0.0, 0.0, false], [1.0, 0.999999, true], [0.25, 0.249999, true], [0.25, 0.25, false], [0.25, 0.250001, false]]:
		_check(InfectedDebrisResolver.resolve(row[0], row[1]) == row[2], "Exact chance boundary")
	var policy: InfectedDebrisPolicy = InfectedDebrisPolicy.new()
	for invalid: float in [-0.1, 1.1, INF, NAN]:
		policy.chance = invalid
		_check(not policy.validate().is_empty(), "Reject invalid probability")
	var scene: FieldPrototypePresenter = (load("res://field_prototype.tscn") as PackedScene).instantiate()
	Fixture.prepare(scene)
	root.add_child(scene)
	Fixture.start(scene)
	await process_frame
	var farming: FarmingController = scene.farming_controller
	scene.world_view.farmer_agent.set_process(false)
	farming.infected_debris_policy.chance = 1.0
	var pos: Vector2i = Vector2i.ZERO
	_prepare_crop(farming, pos)
	var action: FieldAction = FieldAction.new()
	action.kind = Kind.HARVEST
	action.target = pos
	var rng_before: int = farming._debris_rng.state
	var score_before: int = scene.game_state_manager.harvest_count
	scene.game_state_manager.harvest_goal = score_before + 1
	var turn_before: int = scene.game_state_manager.turns_reached
	_check(farming.enqueue_action(action), "Queue eligible harvest")
	_check(farming._debris_rng.state == rng_before and not farming.get_grid_snapshot().get_cell(pos).has_infected_debris, "Queue preserves field and RNG")
	_check(not farming.enqueue_action(action), "Duplicate reservation rejected")
	var queued: FieldAction = farming.get_current_action()
	_check(farming.arrive_at_action(queued.id, pos), "Arrival commits")
	var cell: FieldCellState = farming.get_grid_snapshot().get_cell(pos)
	_check(cell.has_infected_debris and not cell.has_crop and cell.validate().is_empty(), "Debris independent of cleared crop invariants")
	_check(scene.game_state_manager.harvest_count == score_before + 1, "Score increments once")
	_check(scene.game_state_manager.turns_reached == turn_before, "Harvest does not advance turn")
	_check(scene.game_state_manager.harvest_count == scene.game_state_manager.harvest_goal, "Debris commits on victory-threshold harvest")
	_check(not farming.arrive_at_action(queued.id, pos), "Duplicate arrival ignored")
	_check(scene.game_state_manager.harvest_count == score_before + 1, "Duplicate does not score")
	var view: TileInspectorView = InspectorFixture.create()
	root.add_child(view)
	view.display_cell(cell, null)
	_check(view.disease_label.text == "Infected debris", "Inspector exposes residue")
	cell.has_infected_debris = false
	_check(farming.get_grid_snapshot().get_cell(pos).has_infected_debris, "Snapshot detached")
	_check(farming.advance_growth(), "Turn growth succeeds")
	_check(farming.get_grid_snapshot().get_cell(pos).has_infected_debris, "Residue survives turn copy")
	_check(farming.try_plant(pos, SimulationEnums.CropType.CORN), "Plant on residue")
	_check(not farming.get_grid_snapshot().get_cell(pos).has_infected_debris, "Plant clears residue")
	_prepare_crop(farming, pos)
	farming._grid.get_cell(pos).has_active_disease = false
	rng_before = farming._debris_rng.state
	var result: HarvestResult = farming.harvest_crop(pos)
	_check(result.success and is_equal_approx(result.quality_multiplier, 0.7), "Harvest quality retained")
	_check(farming._debris_rng.state == rng_before and not farming.get_grid_snapshot().get_cell(pos).has_infected_debris, "Ineligible harvest skips draw")
	_prepare_crop(farming, pos)
	_check(farming.enqueue_action(action), "Queue stale test")
	queued = farming.get_current_action()
	farming.clear_crop(pos)
	_check(not farming.arrive_at_action(queued.id, pos) and farming._debris_rng.state == rng_before, "Stale action preserves RNG")
	_prepare_crop(farming, pos)
	var live: FieldCellState = farming._grid.get_cell(pos)
	live.sir_state = SimulationEnums.SIRState.S
	live.infected_fraction = 0.0
	_check(not InfectedDebrisResolver.is_eligible(live), "Exposed or recovered without infection excluded")
	live.infected_fraction = 0.1
	_check(InfectedDebrisResolver.is_eligible(live), "Continuous infection eligible")
	live.infected_fraction = 0.0
	live.sir_state = SimulationEnums.SIRState.I
	_check(InfectedDebrisResolver.is_eligible(live), "Categorical infection eligible")
	_prepare_crop(farming, pos)
	farming._grid.get_cell(pos).has_infected_debris = true
	var destination: Vector2i = Vector2i(1, 0)
	_check(farming.transfer_crop(pos, destination), "Move succeeds")
	_check(farming._grid.get_cell(pos).has_infected_debris and not farming._grid.get_cell(destination).has_infected_debris, "Debris does not travel")
	_check(farming.transfer_crop(destination, pos), "Move onto debris succeeds")
	_check(farming._grid.get_cell(pos).has_infected_debris, "Destination debris remains")
	farming.clear_crop(pos)
	_check(farming._grid.get_cell(pos).has_infected_debris, "Crop removal preserves debris")
	var fence: FieldAction = FieldAction.new()
	fence.kind = Kind.FENCE
	fence.target = pos
	_check(farming.enqueue_action(fence), "Fence residue tile")
	queued = farming.get_current_action()
	_check(farming.arrive_at_action(queued.id, pos), "Fence commits")
	_check(not farming._grid.get_cell(pos).has_infected_debris, "Fence clears debris")
	_check(farming.initialize_field(), "Reset lifecycle fixture")
	var conversion: FieldAction = FieldAction.new()
	conversion.kind = Kind.MAKE_PADDY
	conversion.target = pos
	farming._grid.get_cell(pos).has_infected_debris = true
	_check(farming.enqueue_action(conversion), "Convert residue tile")
	queued = farming.get_current_action()
	_check(farming.arrive_at_action(queued.id, pos), "Conversion commits")
	_check(not farming._grid.get_cell(pos).has_infected_debris, "Conversion clears debris")
	_check(farming.initialize_field(), "Reset after conversion")
	rng_before = farming._debris_rng.state
	action.target = Vector2i(-1, 0)
	_check(not farming.enqueue_action(action), "Out-of-field target rejected")
	action.target = pos
	_check(not farming.enqueue_action(action), "Empty target rejected")
	_check(farming.try_plant(pos, SimulationEnums.CropType.CORN), "Prepare immature target")
	_check(not farming.enqueue_action(action), "Immature target rejected")
	_check(farming._debris_rng.state == rng_before, "Invalid targets consume no draw")
	var rejecting: RejectingFarming = RejectingFarming.new()
	rejecting.crop_database = farming.crop_database
	rejecting.terrain_database = farming.terrain_database
	rejecting.initial_soil = farming.initial_soil
	rejecting.initial_abiotic = farming.initial_abiotic
	_check(rejecting.initialize_field(), "Initialize rollback fixture")
	_prepare_crop(rejecting, pos)
	rng_before = rejecting._debris_rng.state
	_check(not rejecting.harvest_crop(pos).success, "Post-draw failure rejected")
	_check(rejecting._grid.get_cell(pos).has_crop and rejecting._debris_rng.state == rng_before, "Failed candidate preserves grid and RNG")
	var outcomes: Array[bool] = []
	farming.infected_debris_policy.chance = 0.25
	for replay: int in range(2):
		_check(farming.initialize_field(), "Replay initialization")
		for index: int in range(20):
			if replay == 1:
				# Unrelated random activity must not perturb the dedicated stream.
				randf()
				randi()
			_prepare_crop(farming, pos)
			_check(farming.harvest_crop(pos).success, "Replay harvest")
			var debris: bool = farming.get_grid_snapshot().get_cell(pos).has_infected_debris
			if replay == 0:
				outcomes.append(debris)
			else:
				_check(debris == outcomes[index], "Seeded replay")
	_prepare_crop(farming, pos)
	rng_before = farming._debris_rng.state
	farming.infected_debris_policy.chance = NAN
	_check(not farming.harvest_crop(pos).success and not farming.initialize_field(), "Invalid policy rejects harvest and initialization")
	_check(farming._grid.get_cell(pos).has_crop and farming._debris_rng.state == rng_before, "Invalid policy preserves session")
	view.free()
	rejecting.free()
	scene.free()
	await process_frame
	if failures.is_empty():
		print("INFECTED_DEBRIS_PASS")
		quit(0)
	else:
		for failure: String in failures:
			print("FAIL: " + failure)
		quit(1)


func _prepare_crop(farming: FarmingController, pos: Vector2i) -> void:
	farming.clear_crop(pos)
	_check(farming.try_plant(pos, SimulationEnums.CropType.CORN), "Prepare crop")
	var cell: FieldCellState = farming._grid.get_cell(pos)
	cell.growth_elapsed_ticks = farming.crop_database.get_crop(cell.crop_type).growth_ticks
	cell.has_active_disease = true
	cell.sir_state = SimulationEnums.SIRState.I
	cell.susceptible_fraction = 0.8
	cell.infected_fraction = 0.2
	cell.yield_quality_loss = 0.3


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
