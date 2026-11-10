extends SceneTree
## R1–R10 / all three inoculation feature files.
const GameplayFixture = preload("res://tests/logic/gameplay_test_fixture.gd")
const QueueDriver = preload("res://tests/logic/queued_action_test_driver.gd")
var failures: PackedStringArray = []

class RejectedTurn:
	extends SimulationController
	func process_turn(_grid: FieldGridState, _database: DiseaseDatabase) -> bool:
		rng.randf()
		beta_cap_count = 99
		last_error = "Deliberate failure"
		return false

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		print("FAIL: " + message)

func _farm() -> FarmingController:
	var farm: FarmingController = FarmingController.new()
	farm.crop_database = load("res://src/data/databases/crop_database.tres") as CropDatabase
	farm.terrain_database = load("res://src/data/databases/terrain_database.tres") as TerrainDatabase
	farm.initial_soil = SoilState.new()
	farm.initial_abiotic = AbioticState.new()
	farm.terrain_bands = [SimulationEnums.TerrainType.DRY_SOIL]
	_check(farm.initialize_field(), "Initialize 9x6 fixture")
	return farm

func _run() -> void:
	var farm: FarmingController = _farm()
	var coords: Vector2i = Vector2i(2, 1)
	_check(not farm.inoculate_crop(coords), "Empty crop rejected")
	_check(not farm.inoculate_crop(Vector2i(-1, 0)), "Outside grid rejected")
	_check(farm.try_plant(coords, SimulationEnums.CropType.SUGARCANE), "Plant seedling")
	var action: FieldAction = FieldAction.new()
	action.kind = SimulationEnums.FieldActionKind.INOCULATE
	action.target = coords
	_check(farm.enqueue_action(action), "Queue protection")
	_check(not farm.get_grid_snapshot().get_cell(coords).is_inoculated(), "No early mutation")
	_check(not farm.enqueue_action(action), "Reserved target rejected")
	_check(not farm.advance_growth(), "Pending action blocks turn")
	var queued: FieldAction = farm.get_current_action()
	_check(not farm.arrive_at_action(queued.id + 1, coords), "Outdated arrival rejected")
	_check(farm.arrive_at_action(queued.id, coords), "Arrival commits")
	var cell: FieldCellState = farm.get_grid_snapshot().get_cell(coords)
	_check(cell.inoculation_bonus == 0.25 and cell.inoculation_turns_remaining == 3, "Seedling efficacy and duration")
	cell.inoculation_bonus = 0.9
	_check(farm.get_grid_snapshot().get_cell(coords).inoculation_bonus == 0.25, "Snapshot isolation")
	_check(farm.transfer_crop(coords, Vector2i(4, 3)), "Move protection with crop")
	coords = Vector2i(4, 3)
	_check(farm.get_grid_snapshot().get_cell(coords).is_inoculated(), "Moved crop protected")
	_check(farm.get_grid_snapshot().get_cell(Vector2i(2, 1)).inoculation_bonus == 0.0, "Move clears source")
	var turns: TurnController = TurnController.new()
	turns.farming_controller = farm
	for expected: int in [2, 1, 0]:
		_check(turns.advance_turn(), "Protection turn completes")
		_check(farm.get_grid_snapshot().get_cell(coords).inoculation_turns_remaining == expected, "Exact expiry boundary")
	_check(not farm.get_grid_snapshot().get_cell(coords).is_inoculated(), "Neutral after expiration")
	_check(farm.inoculate_crop(coords), "Vegetative reapplication")
	_check(farm.get_grid_snapshot().get_cell(coords).inoculation_bonus == 0.25, "Vegetative bonus")
	var rejected: RejectedTurn = RejectedTurn.new()
	rejected.rng.seed = 42
	var rng_before: int = rejected.rng.state
	turns.simulation_controller = rejected
	var clock_before: int = turns.turn_index
	_check(not turns.advance_turn(), "Failed turn rejected")
	_check(rejected.rng.state == rng_before and rejected.beta_cap_count == 0 and turns.turn_index == clock_before, "Rollback RNG counters clock")
	_check(farm.get_grid_snapshot().get_cell(coords).inoculation_turns_remaining == 3, "Failed turn preserves protection")
	turns.simulation_controller = SimulationController.new()
	farm.inoculation_profile.humid_weather_decay = 0.2
	_check(turns.advance_turn(), "Configured weather decay")
	_check(is_equal_approx(farm.get_grid_snapshot().get_cell(coords).inoculation_bonus, 0.15), "Humidity interpolates decay")
	_check(farm.inoculate_crop(coords), "Refresh without stacking")
	_check(farm.get_grid_snapshot().get_cell(coords).inoculation_bonus == 0.25, "Refresh resets bonus")
	farm.inoculation_profile.dry_weather_decay = 1.0
	_check(turns.advance_turn(), "Early decay expiration")
	_check(not farm.get_grid_snapshot().get_cell(coords).is_inoculated(), "Zero bonus clears duration")
	farm.inoculation_profile = InoculationProfile.new()
	_check(farm.inoculate_crop(coords), "Reapply before removal")
	_check(farm.remove_crop(coords), "Remove crop")
	_check(farm.get_grid_snapshot().get_cell(coords).inoculation_bonus == 0.0, "Removal resets")
	coords = Vector2i(0, 5)
	_check(farm.try_plant(coords, SimulationEnums.CropType.SUGARCANE), "Plant mature example")
	var crop: CropData = farm.crop_database.get_crop(SimulationEnums.CropType.SUGARCANE)
	for tick: int in range(crop.growth_ticks * 3):
		_check(farm.advance_growth(), "Grow crop")
	_check(farm.inoculate_crop(coords), "Mature application")
	_check(farm.get_grid_snapshot().get_cell(coords).inoculation_bonus == 0.15, "Mature bonus")
	_check(farm.harvest_crop(coords).success, "Harvest protected crop")
	_check(farm.get_grid_snapshot().get_cell(coords).inoculation_bonus == 0.0, "Harvest clears")
	farm.initial_soil.moisture = 0.29
	_check(farm.initialize_field() and farm.try_plant(coords, SimulationEnums.CropType.SUGARCANE), "Dry fixture")
	_check(not farm.inoculate_crop(coords), "Dry soil rejected")
	farm.initial_soil.moisture = 0.3
	_check(farm.initialize_field() and farm.try_plant(coords, SimulationEnums.CropType.SUGARCANE), "Boundary fixture")
	_check(farm.inoculate_crop(coords), "Inclusive moisture boundary")
	action.target = coords
	_check(farm.enqueue_action(action), "Queue stale request")
	queued = farm.get_current_action()
	_check(farm.remove_crop(coords), "Change queued target")
	if queued != null:
		_check(not farm.arrive_at_action(queued.id, coords) and not farm.has_pending_actions(), "Stale task cleanup")
	_check(farm.try_plant(coords, SimulationEnums.CropType.SUGARCANE) and farm.enqueue_action(action), "Queue cancellable action")
	farm.cancel_actions()
	_check(not farm.has_pending_actions() and not farm.get_grid_snapshot().get_cell(coords).is_inoculated(), "Cancellation preserves untreated state")
	farm.inoculation_profile.duration_turns = 0
	_check(not farm.inoculate_crop(coords), "Invalid profile rejected")
	farm.inoculation_profile.duration_turns = 3
	var invalid: FieldCellState = farm.get_grid_snapshot().get_cell(coords)
	invalid.soil = null
	_check(not farm._inoculation_error(invalid).is_empty(), "Missing soil rejected")
	invalid.dead_fraction = 1.0
	_check(not farm._inoculation_error(invalid).is_empty(), "Dead crop rejected")
	farm.free()
	turns.free()
	_transmission_tests()
	if failures.is_empty():
		print("SEED_INOCULATION_PASS")
	quit(0 if failures.is_empty() else 1)

func _transmission_tests() -> void:
	var disease: DiseaseData = (load("res://src/data/databases/default_disease_database.tres") as DiseaseDatabase).get_disease(SimulationEnums.DiseaseId.RICE_BLAST).duplicate() as DiseaseData
	disease.transmission_modifier_profile = null
	var environment: AbioticState = AbioticState.new()
	var soil: SoilState = SoilState.new()
	var baseline: TransmissionModifiers.Result = TransmissionModifiers.evaluate(disease, environment, soil, null, 0.5)
	for bonus: float in [0.25, 0.15, 0.0]:
		var response: TransmissionModifiers.Result = TransmissionModifiers.evaluate(disease, environment, soil, null, 0.5, bonus)
		_check(is_equal_approx(response.effective_beta, baseline.effective_beta * (1.0 - bonus)), "Exact recipient multiplier")
		_check(TransmissionModifiers.evaluate(disease, environment, soil, null, 0.0, bonus).hazard == 0.0, "Zero pressure remains zero")
	var capped: DiseaseData = disease.duplicate() as DiseaseData
	capped.beta = 10.0
	capped.transmission_modifier_profile = TransmissionModifierProfile.new()
	capped.transmission_modifier_profile.maximum_effective_beta = 8.0
	_check(is_equal_approx(TransmissionModifiers.evaluate(capped, environment, soil, null, 1.0, 0.25).effective_beta, 7.5), "Protection applied before cap")
	for algorithm: int in [0, 1, 2]:
		var grid: FieldGridState = FieldGridState.new()
		_check(grid.initialize(2, 1, environment), "Initialize paired model grid")
		for x: int in range(2):
			var cell: FieldCellState = grid.get_cell(Vector2i(x, 0))
			cell.terrain_type = SimulationEnums.TerrainType.PADDY_MUD
			cell.soil = soil.copy()
			cell.has_crop = true
			cell.crop_type = SimulationEnums.CropType.RICE
			cell.reset_crop_state()
		var source: FieldCellState = grid.get_cell(Vector2i.ZERO)
		source.has_active_disease = true
		source.active_disease_id = disease.disease_id
		source.susceptible_fraction = 0.0
		source.infected_fraction = 1.0
		source.sir_state = SimulationEnums.SIRState.I
		var treated: FieldGridState = grid.copy()
		treated.get_cell(Vector2i(1, 0)).inoculation_bonus = 0.25
		treated.get_cell(Vector2i(1, 0)).inoculation_turns_remaining = 3
		var database: DiseaseDatabase = DiseaseDatabase.new()
		database.diseases = [disease]
		var simulation: SimulationController = SimulationController.new()
		simulation.algorithm_override = algorithm
		simulation.rng.seed = 42
		var neighbors: Array[FieldCellState] = [source]
		var plain_hazard: float = simulation._transmission(grid.get_cell(Vector2i(1, 0)), disease, neighbors, environment).hazard
		var treated_hazard: float = simulation._transmission(treated.get_cell(Vector2i(1, 0)), disease, neighbors, environment).hazard
		_check(is_equal_approx(treated_hazard, plain_hazard * 0.75), "All model callers use protection")
		_check(simulation.process_turn(grid, database), "Untreated model transition")
		simulation.rng.seed = 42
		_check(simulation.process_turn(treated, database), "Treated model transition")
		_check(grid.validate().is_empty() and treated.validate().is_empty(), "Compartment conservation")
		if algorithm != 2:
			_check(treated.get_cell(Vector2i(1, 0)).susceptible_fraction > grid.get_cell(Vector2i(1, 0)).susceptible_fraction, "Deterministic infection reduction")

func _scene_tests() -> void:
	var scene: FieldPrototypePresenter = (load("res://field_prototype.tscn") as PackedScene).instantiate() as FieldPrototypePresenter
	GameplayFixture.prepare(scene)
	root.add_child(scene)
	await process_frame
	GameplayFixture.start(scene)
	_check(scene.inoculate_button != null and scene.inoculation_cursor != null, "Saved toolbar and cursor wired")
	var coords: Vector2i = Vector2i(1, 1)
	_check(scene.farming_controller.try_plant(coords, SimulationEnums.CropType.SUGARCANE), "Scene planting")
	scene.inoculate_button.pressed.emit()
	_check(scene._tool_mode == FieldPrototypePresenter.ToolMode.TOOL_INOCULATE, "Toolbar mode")
	scene._on_cell_clicked(coords)
	await QueueDriver.finish(scene)
	_check(scene.farming_controller.get_grid_snapshot().get_cell(coords).is_inoculated(), "Farmer applies protection")
	scene._enter_inspect_mode()
	scene._on_cell_clicked(coords)
	_check(scene.tile_inspector.growth_label.text.contains("Inoculated: Active") and scene.tile_inspector.growth_label.text.contains("25%"), "Inspector protection details")
	if OS.get_cmdline_user_args().has("--inoculation-preview"):
		scene.world_view.crop_overlay.show()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/inoculation_preview.png")
	_check(scene.world_view.crop_overlay._snapshot.get_cell(coords).is_inoculated(), "Overlay receives detached protection")
	var visible_before: bool = scene.world_view.crop_overlay.visible
	var toggle: InputEventKey = InputEventKey.new()
	toggle.keycode = KEY_O
	toggle.pressed = true
	root.push_input(toggle)
	_check(scene.world_view.crop_overlay.visible != visible_before, "O toggles protection overlay")
	for turn: int in range(3):
		_check(scene.turn_controller.advance_turn(), "Scene protection ages")
	_check(scene.tile_inspector.growth_label.text.contains("Inoculated: Inactive"), "Inspector refreshes expiration")
	_check(not scene.world_view.crop_overlay._snapshot.get_cell(coords).is_inoculated(), "Overlay refreshes expiration")
	scene._on_inoculate_pressed()
	scene._on_invalid_tool_target(Vector2i(-1, -1))
	_check(scene.tile_inspector.visible and scene.tile_inspector.title_label.text == "Invalid target", "Inspector rejection feedback")
	scene.queue_free()
	await process_frame
