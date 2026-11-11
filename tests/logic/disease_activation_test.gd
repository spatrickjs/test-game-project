extends SceneTree

class InvalidRequest:
	extends DiseaseActivationController
	func evaluate(grid: FieldGridState, diseases: DiseaseDatabase, turn: int, active_filter: int = -1, allow_introduction: bool = true) -> Result:
		var result: Result = super.evaluate(grid, diseases, turn, active_filter, allow_introduction)
		if result.request != null:
			result.request.coordinates = Vector2i(-1, -1)
		return result

class Fixture:
	extends RefCounted
	var farming: FarmingController = FarmingController.new()
	var turns: TurnController = TurnController.new()
	var activation: DiseaseActivationController = DiseaseActivationController.new()
	var game: GameStateManager = GameStateManager.new()
	func setup(algorithm: int = 0) -> bool:
		farming.crop_database = load("res://src/data/databases/crop_database.tres") as CropDatabase
		farming.terrain_database = load("res://src/data/databases/terrain_database.tres") as TerrainDatabase
		farming.initial_soil = SoilState.new()
		farming.initial_abiotic = AbioticState.new()
		farming.field_size = Vector2i(6, 1)
		farming.terrain_bands = [SimulationEnums.TerrainType.PADDY_MUD]
		turns.farming_controller = farming
		turns.game_state_manager = game
		turns.disease_database = DiseaseDatabase.new()
		var disease: DiseaseData = (load("res://src/data/resources/diseases/rice_blast.tres") as DiseaseData).copy()
		# Isolated mathematical fixture, not modifications to authored disease settings.
		disease.beta = 0.0
		disease.gamma = 1.0
		disease.mortality_probability = 0.0
		turns.disease_database.diseases = [disease]
		turns.simulation_controller.algorithm_override = algorithm
		turns.simulation_controller.rng.seed = 55
		turns.disease_activation_controller = activation
		activation.debug_introductions = false
		activation.policy = DiseaseActivationPolicy.new()
		activation.policy.first_eligible_turn = 1
		activation.policy.chance_per_eligible_turn = 1.0
		activation.policy.cooldown_turns = 2
		activation.reset_session()
		return farming.initialize_field()
	func plant_all() -> bool:
		for x: int in range(6):
			if not farming.try_plant(Vector2i(x, 0), SimulationEnums.CropType.RICE):
				return false
		return true
	func dispose() -> void:
		farming.free()
		turns.free()
		activation.free()
		game.free()

var failures: PackedStringArray = PackedStringArray()
var notifications: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, label: String) -> void:
	if not value:
		failures.append(label)
		printerr("FAIL: " + label)

func _run() -> void:
	for algorithm: int in [0, 1, 2]:
		var f: Fixture = Fixture.new()
		check(f.setup(algorithm) and f.plant_all(), "Initialize isolated fixture")
		check(not f.turns.advance_turn() and f.turns.turn_index == 0, "Menu blocks direct turns")
		f.game.start_game()
		f.activation.introduction_committed.connect(func(_id: int, _cell: Vector2i, turn: int) -> void:
			notifications += 1
			check(turn == f.turns.turn_index, "Notification sees committed clock")
		)
		check(f.turns.advance_turn(), "First activation turn succeeds")
		var request: DiseaseActivationRequest = f.farming.last_turn_introduction
		check(request != null, "Certain introduction produces a request")
		if request != null:
			var cell: FieldCellState = f.farming.get_grid_snapshot().get_cell(request.coordinates)
			check(cell.infected_fraction == (1.0 if algorithm == 2 else 0.2) and cell.recovered_immune_fraction == 0.0, "New infection does not progress on its introduction turn")
		check(f.activation.get_state_snapshot().introductions_committed == 1, "One introduction counted")
		check(f.turns.advance_turn() and f.farming.last_turn_introduction == null, "First cooldown turn skipped")
		if request != null and algorithm != 2:
			check(f.farming.get_grid_snapshot().get_cell(request.coordinates).recovered_immune_fraction > 0.0, "Existing infection progresses on the next turn")
		check(f.turns.advance_turn() and f.farming.last_turn_introduction == null, "Second cooldown turn skipped")
		check(f.turns.advance_turn() and f.farming.last_turn_introduction != null, "Introduction resumes after N completed cooldown turns")
		for turn: int in range(4):
			check(f.turns.advance_turn(), "Subsequent turn succeeds")
		check(f.activation.get_state_snapshot().introductions_committed == 2, "Session limit enforced")
		var receipt: HarvestResult = HarvestResult.new()
		receipt.success = true
		receipt.score = 1.0
		f.game.score_goal = 1
		f.game.record_harvest(receipt)
		check(not f.turns.advance_turn(), "Victory blocks direct turns")
		f.dispose()
	_test_policy_and_replay()
	_test_conflicts()
	_test_rollback()
	await _test_saved_scene()
	if failures.is_empty():
		print("DISEASE_ACTIVATION_PASS")
	quit(0 if failures.is_empty() else 1)

func _test_policy_and_replay() -> void:
	var f: Fixture = Fixture.new()
	check(f.setup(), "Initialize policy fixture")
	f.game.start_game()
	var random_before: int = f.activation.get_state_snapshot().rng_state
	check(f.turns.advance_turn(), "Empty field permits ordinary turn")
	check(f.activation.get_state_snapshot().rng_state == random_before, "No host consumes no activation randomness")
	check(f.plant_all(), "Plant policy fixture")
	var detached: FieldGridState = f.farming.get_grid_snapshot()
	var proposal: DiseaseActivationController.Result = f.activation.evaluate(detached, f.turns.disease_database, 1)
	for draw: int in range(20):
		f.turns.simulation_controller.rng.randf()
	var repeated: DiseaseActivationController.Result = f.activation.evaluate(detached, f.turns.disease_database, 1)
	check(proposal.request.coordinates == repeated.request.coordinates and proposal.next_state.rng_state == repeated.next_state.rng_state, "Simulation random draws cannot change activation selection")
	check(f.activation.get_state_snapshot().rng_state == random_before and not detached.get_cell(proposal.request.coordinates).has_active_disease, "Planning mutates neither committed history nor field snapshot")
	for x: int in range(detached.width):
		detached.get_cell(Vector2i(x, 0)).crop_type = SimulationEnums.CropType.CORN
	check(f.activation.evaluate(detached, f.turns.disease_database, 1).request == null, "Incompatible crops cannot receive introductions")
	f.activation.policy.enabled = false
	check(f.turns.advance_turn() and f.farming.last_turn_introduction == null, "Disabled activation")
	f.activation.policy.enabled = true
	f.activation.policy.first_eligible_turn = 5
	check(f.turns.advance_turn() and f.farming.last_turn_introduction == null, "Before first eligible turn")
	f.activation.policy.first_eligible_turn = 1
	f.activation.policy.chance_per_eligible_turn = 0.0
	check(f.turns.advance_turn() and f.farming.last_turn_introduction == null, "Zero chance never introduces")
	f.activation.policy.chance_per_eligible_turn = 1.0
	f.activation.policy.max_introductions_per_session = 0
	check(f.turns.advance_turn() and f.farming.last_turn_introduction == null, "Zero limit disables introductions")
	f.activation.policy.max_introductions_per_session = 2
	f.activation.policy.chance_per_eligible_turn = NAN
	var clock_before: int = f.turns.turn_index
	check(not f.turns.advance_turn() and f.turns.turn_index == clock_before, "Invalid policy rejects turn")
	f.activation.policy.chance_per_eligible_turn = 1.0
	f.activation.policy.allowed_disease_ids.append(SimulationEnums.DiseaseId.RICE_TUNGRO)
	check(not f.turns.advance_turn(), "Unregistered permitted disease rejected")
	f.activation.policy.allowed_disease_ids = [SimulationEnums.DiseaseId.RICE_BLAST]
	var action: FieldAction = FieldAction.new()
	action.kind = SimulationEnums.FieldActionKind.REMOVE_CROP
	action.target = Vector2i.ZERO
	check(f.farming.enqueue_action(action) and not f.turns.advance_turn(), "Farmer queue blocks turns")
	f.farming.cancel_actions()
	f.turns.reset_clock()
	check(f.turns.advance_turn(), "Replay baseline succeeds")
	var first: Vector2i = f.farming.last_turn_introduction.coordinates
	check(f.farming.initialize_field() and f.plant_all(), "Reset fixture field")
	f.turns.reset_clock()
	f.turns.reset_clock()
	check(f.activation.get_state_snapshot().introductions_committed == 0 and f.activation.get_state_snapshot().rng_state == random_before, "Repeated reset is idempotent")
	check(f.turns.advance_turn() and f.farming.last_turn_introduction.coordinates == first, "Seeded restart repeats selection")
	f.game.turn_limit = 2
	f.activation.policy.cooldown_turns = 0
	var state: DiseaseActivationState = f.activation.get_state_snapshot()
	state.cooldown_remaining = 0
	f.activation.commit_state(state)
	check(f.turns.advance_turn() and f.farming.last_turn_introduction == null, "Terminal turn skips introduction")
	check(f.game.current_state == GameStateManager.State.GAME_OVER and not f.turns.advance_turn(), "Game over enforced in Logic")
	f.dispose()

func _test_conflicts() -> void:
	var f: Fixture = Fixture.new()
	check(f.setup() and f.plant_all(), "Initialize identity fixture")
	f.game.start_game()
	var other: DiseaseData = f.turns.disease_database.diseases[0].copy()
	other.disease_id = SimulationEnums.DiseaseId.RICE_TUNGRO
	other.display_name = "Identity test fixture"
	f.turns.disease_database.diseases.append(other)
	check(f.farming.seed_infection(Vector2i.ZERO, other.disease_id, f.turns.disease_database, f.turns.simulation_controller), "Manual debug seeding still works")
	var before: int = f.activation.get_state_snapshot().rng_state
	check(f.turns.advance_turn() and f.farming.last_turn_introduction == null, "Different retained disease blocks automatic introduction")
	check(f.activation.get_state_snapshot().rng_state == before, "Conflict consumes no activation randomness")
	check(f.farming.initialize_field() and f.plant_all(), "Reset filter fixture")
	f.turns.simulation_controller.active_disease_filter = other.disease_id
	check(f.turns.advance_turn() and f.farming.last_turn_introduction == null, "Active disease filter respected")
	f.turns.simulation_controller.active_disease_filter = -1
	check(f.turns.advance_turn(), "Allowed identity selected")
	f.activation.policy.allowed_disease_ids.append(other.disease_id)
	var clear_cooldown: DiseaseActivationState = f.activation.get_state_snapshot()
	clear_cooldown.cooldown_remaining = 0
	f.activation.commit_state(clear_cooldown)
	check(f.farming.seed_infection(Vector2i(5, 0) if f.farming.last_turn_introduction.coordinates != Vector2i(5, 0) else Vector2i.ZERO, other.disease_id, f.turns.disease_database, f.turns.simulation_controller), "Manual alternative identity can coexist in zero-spread fixture")
	check(f.turns.advance_turn() and f.farming.last_turn_introduction == null, "Mixed identity board skips introductions")
	f.dispose()

func _test_rollback() -> void:
	var f: Fixture = Fixture.new()
	check(f.setup(2) and f.plant_all(), "Initialize rollback fixture")
	f.game.start_game()
	check(f.farming.seed_infection(Vector2i.ZERO, SimulationEnums.DiseaseId.RICE_BLAST, f.turns.disease_database, f.turns.simulation_controller), "Seed rollback simulation")
	var invalid: InvalidRequest = InvalidRequest.new()
	invalid.policy = f.activation.policy
	invalid.debug_introductions = false
	invalid.reset_session()
	f.turns.disease_activation_controller = invalid
	var events: Array[int] = [0]
	invalid.introduction_committed.connect(func(_id: int, _cell: Vector2i, _turn: int) -> void: events[0] += 1)
	var weather: WeatherManager = WeatherManager.new()
	weather.debug_moisture_updates = false
	weather.rainfall_per_turn = 0.1
	f.turns.weather_manager = weather
	var before: FieldGridState = f.farming.get_grid_snapshot()
	var rng_before: int = f.turns.simulation_controller.rng.state
	var activation_before: int = invalid.get_state_snapshot().rng_state
	check(not f.turns.advance_turn(), "Invalid late request rejects entire turn")
	var after: FieldGridState = f.farming.get_grid_snapshot()
	for x: int in range(6):
		var old: FieldCellState = before.get_cell(Vector2i(x, 0))
		var cell: FieldCellState = after.get_cell(Vector2i(x, 0))
		check(old.infected_fraction == cell.infected_fraction and old.growth_elapsed_ticks == cell.growth_elapsed_ticks and old.growth_remainder == cell.growth_remainder and old.soil.moisture == cell.soil.moisture, "Late rejection preserves field")
	check(f.turns.simulation_controller.rng.state == rng_before and invalid.get_state_snapshot().rng_state == activation_before, "Both random streams roll back")
	check(f.turns.turn_index == 0 and invalid.get_state_snapshot().introductions_committed == 0 and events[0] == 0 and weather.last_moisture_summary.is_empty(), "No counters, clock, signals or diagnostics survive failure")
	f.turns.disease_activation_controller = f.activation
	check(f.turns.advance_turn(), "Retry succeeds after rejected request")
	invalid.free()
	weather.free()
	f.dispose()

func _test_saved_scene() -> void:
	var scene: FieldPrototypePresenter = (load("res://field_prototype.tscn") as PackedScene).instantiate() as FieldPrototypePresenter
	# Explicit fixture, preserving the saved all-grass world and shared policy.
	scene.farming_controller.terrain_bands = [SimulationEnums.TerrainType.PADDY_MUD]
	scene.turn_controller.weather_manager.debug_moisture_updates = false
	var activation: DiseaseActivationController = scene.turn_controller.disease_activation_controller
	check(activation != null and scene.game_state_manager == scene.turn_controller.game_state_manager, "Scene saves activation and shared session references")
	if activation == null:
		scene.free()
		return
	activation.policy = activation.policy.duplicate() as DiseaseActivationPolicy
	activation.policy.first_eligible_turn = 1
	activation.policy.chance_per_eligible_turn = 1.0
	activation.debug_introductions = false
	root.add_child(scene)
	await process_frame
	check(not scene.turn_controller.advance_turn(), "Saved scene starts in menu")
	scene._on_start_pressed()
	check(scene.farming_controller.try_plant(Vector2i.ZERO, SimulationEnums.CropType.RICE), "Plant saved scene fixture")
	check(scene.turn_controller.advance_turn() and activation.get_state_snapshot().introductions_committed == 1, "Saved scene activates during play")
	scene.game_state_manager.check_turn_limit(scene.game_state_manager.turn_limit)
	check(not scene.turn_controller.advance_turn(), "Saved scene blocks after game over")
	scene._on_play_again_pressed()
	check(scene.game_state_manager.is_playing() and scene.turn_controller.turn_index == 0 and activation.get_state_snapshot().introductions_committed == 0, "Play Again clears activation and session history")
	check(scene.farming_controller.try_plant(Vector2i.ZERO, SimulationEnums.CropType.RICE) and scene.turn_controller.advance_turn(), "Restart remains playable")
	scene.queue_free()
	await process_frame
