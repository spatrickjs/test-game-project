extends SceneTree
const GameplayFixture = preload("res://tests/logic/gameplay_test_fixture.gd")
const QueueDriver = preload("res://tests/logic/queued_action_test_driver.gd")
const CycleChecks = preload("res://tests/logic/weather_cycle_checks.gd")

class RejectedTurn:
	extends SimulationController
	func process_turn(_grid_state: FieldGridState, _diseases: DiseaseDatabase) -> bool:
		last_error = "Deliberate failure after weather and growth"
		return false

var _failures: PackedStringArray = PackedStringArray()
var _changes: int = 0
var _turns: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_failures.append_array(CycleChecks.new().run())
	_check(is_equal_approx(SoilMoistureModel.next_moisture(0.5, 0.1, 0.02, 2.0), 0.68), "Pure rainfall/evaporation formula")
	_check(SoilMoistureModel.next_moisture(0.9, 1.0, 0.0, 2.0) == 1.0, "Moisture upper clamp")
	_check(SoilMoistureModel.next_moisture(0.1, 0.0, 1.0, 1.0) == 0.0, "Moisture lower clamp")
	_check(is_nan(SoilMoistureModel.next_moisture(NAN, 0.0, 0.0, 1.0)), "Invalid moisture rejected")
	var farming: FarmingController = FarmingController.new()
	farming.crop_database = load("res://src/data/databases/crop_database.tres") as CropDatabase
	farming.terrain_database = load("res://src/data/databases/terrain_database.tres") as TerrainDatabase
	farming.initial_soil = SoilState.new()
	farming.initial_abiotic = AbioticState.new()
	farming.field_size = Vector2i(3, 1)
	farming.terrain_bands = [SimulationEnums.TerrainType.DRY_SOIL, SimulationEnums.TerrainType.GRASS]
	_check(farming.initialize_field(), "Initialize weather fixture")
	var weather: WeatherManager = WeatherManager.new()
	var tools: SoilToolController = SoilToolController.new()
	tools.farming_controller = farming
	var turns: TurnController = TurnController.new()
	turns.farming_controller = farming
	turns.weather_manager = weather
	turns.turn_completed.connect(func(_index: int) -> void: _turns += 1)
	farming.cell_changed.connect(func(_coordinates: Vector2i) -> void: _changes += 1)
	weather.rainfall_per_turn = 0.1
	weather.evaporation_per_turn = 0.02
	_check(turns.advance_turn(), "Next Turn invokes weather")
	var snapshot: FieldGridState = farming.get_grid_snapshot()
	_check(is_equal_approx(snapshot.get_cell(Vector2i.ZERO).soil.moisture, 0.58), "Inspector rates applied")
	_check(is_equal_approx(snapshot.get_cell(Vector2i(1, 0)).soil.moisture, 0.58), "All soil tiles update, including empty tiles")
	_check(snapshot.get_cell(Vector2i(2, 0)).soil == null, "Grass remains soil-free")
	_check(snapshot.abiotic_state.temperature_celsius == 25.0 and snapshot.abiotic_state.relative_humidity == 0.5, "Hydration weather does not overwrite shared ambient state")
	_check(_turns == 1 and _changes == 0, "Weather uses one completed-turn notification")
	weather.rainfall_per_turn = 0.2
	_check(turns.advance_turn(), "Runtime Inspector change accepted")
	_check(is_equal_approx(farming.get_grid_snapshot().get_cell(Vector2i.ZERO).soil.moisture, 0.76), "New rates take effect next turn")
	weather.enabled = false
	_check(turns.advance_turn(), "Disabled weather still allows turns")
	_check(is_equal_approx(farming.get_grid_snapshot().get_cell(Vector2i.ZERO).soil.moisture, 0.76), "Disabled weather preserves moisture")
	weather.enabled = true
	weather.source_mode = WeatherManager.SourceMode.CSV
	var clock_before: int = turns.turn_index
	_check(not turns.advance_turn() and turns.turn_index == clock_before, "Unsupported source rejected without advancing clock")
	_check(turns.last_error.contains("not implemented"), "External source hook has explicit diagnostic")
	weather.source_mode = WeatherManager.SourceMode.INSPECTOR
	weather.rainfall_per_turn = NAN
	_check(not turns.advance_turn(), "Invalid weather rejected")
	weather.rainfall_per_turn = 0.0
	weather.base_temperature_celsius = 35.0
	weather.temperature_evaporation_sensitivity = 0.1
	weather.ambient_humidity = 0.0
	var sample: FieldGridState = farming.get_grid_snapshot()
	_check(weather.apply_to_grid(sample, 0), "Temperature/humidity response evaluated")
	_check(is_equal_approx(sample.get_cell(Vector2i.ZERO).soil.moisture, 0.70), "Warm/dry evaporation uses configured factors")
	weather.maximum_evaporation_factor = 1.0
	sample = farming.get_grid_snapshot()
	_check(weather.apply_to_grid(sample, 0), "Evaporation factor cap evaluated")
	_check(is_equal_approx(sample.get_cell(Vector2i.ZERO).soil.moisture, 0.74), "Inspector factor cap applied")
	weather.base_temperature_celsius = 25.0
	weather.ambient_humidity = 0.5
	weather.maximum_evaporation_factor = 3.0
	weather.fluctuations_enabled = true
	weather.cycle_length_turns = 4
	weather.rainfall_per_turn = 0.1
	weather.rainfall_amplitude = 0.05
	weather.temperature_amplitude = 0.0
	var first: FieldGridState = farming.get_grid_snapshot()
	var repeat: FieldGridState = farming.get_grid_snapshot()
	_check(weather.apply_to_grid(first, 1) and weather.apply_to_grid(repeat, 5), "Cycle evaluations succeed")
	_check(is_equal_approx(first.get_cell(Vector2i.ZERO).soil.moisture, 0.89) and first.get_cell(Vector2i.ZERO).soil.moisture == repeat.get_cell(Vector2i.ZERO).soil.moisture, "Weather repeats deterministically by turn index")
	# Weather occurs before growth; a severe dry-out immediately stalls this crop.
	weather.fluctuations_enabled = false
	weather.rainfall_per_turn = 0.0
	weather.evaporation_per_turn = 1.0
	_check(farming.try_plant(Vector2i.ZERO, SimulationEnums.CropType.SUGARCANE), "Plant hydration fixture")
	var before: FieldCellState = farming.get_grid_snapshot().get_cell(Vector2i.ZERO)
	var previous_simulation: SimulationController = turns.simulation_controller
	turns.simulation_controller = RejectedTurn.new()
	clock_before = turns.turn_index
	var summary_before_failure: String = weather.last_moisture_summary
	_check(not turns.advance_turn(), "Later processing failure rejects weather turn")
	var after: FieldCellState = farming.get_grid_snapshot().get_cell(Vector2i.ZERO)
	_check(after.soil.moisture == before.soil.moisture and after.vitality == before.vitality and after.yield_quality_loss == before.yield_quality_loss and after.growth_remainder == before.growth_remainder and turns.turn_index == clock_before, "Weather, lifecycle and clock fully roll back")
	_check(weather.last_moisture_summary == summary_before_failure, "Failed turn emits no committed-weather diagnostic")
	turns.simulation_controller = previous_simulation
	_check(turns.advance_turn(), "Weather/growth turn succeeds")
	after = farming.get_grid_snapshot().get_cell(Vector2i.ZERO)
	_check(after.soil.moisture == 0.0 and after.growth_elapsed_ticks == 0 and after.vitality < 1.0, "Moisture change precedes growth")
	# Tools are local, bounded, transactional, and do not advance turns.
	_changes = 0
	clock_before = turns.turn_index
	tools.water_infusion_amount = 0.25
	_check(tools.water(Vector2i.ZERO), "Water occupied tile")
	after = farming.get_grid_snapshot().get_cell(Vector2i.ZERO)
	_check(is_equal_approx(after.soil.moisture, 0.25) and after.vitality < 1.0 and after.growth_elapsed_ticks == 0, "Water modifies soil without repairing crop state")
	_check(_changes == 1 and turns.turn_index == clock_before, "One action notification and no time advance")
	tools.nitrogen_boost_amount = 0.2
	tools.potassium_boost_amount = 0.3
	_check(tools.fertilize(Vector2i(1, 0)), "Fertilize empty soil")
	after = farming.get_grid_snapshot().get_cell(Vector2i(1, 0))
	_check(is_equal_approx(after.soil.nitrogen, 0.7) and is_equal_approx(after.soil.potassium, 0.8) and after.soil.phosphorus == 0.5 and after.soil.soil_ph == 7.0, "Independent N/K additions preserve other metrics")
	_check(farming.get_grid_snapshot().get_cell(Vector2i.ZERO).soil.nitrogen == 0.5, "Neighbor soil remains independent")
	for action: int in range(6):
		_check(tools.water(Vector2i.ZERO) and tools.fertilize(Vector2i(1, 0)), "Repeated actions succeed")
	_check(farming.get_grid_snapshot().get_cell(Vector2i.ZERO).soil.moisture == 1.0 and farming.get_grid_snapshot().get_cell(Vector2i(1, 0)).soil.nitrogen == 1.0 and farming.get_grid_snapshot().get_cell(Vector2i(1, 0)).soil.potassium == 1.0, "Repeated actions saturate at one")
	var changes_before: int = _changes
	_check(tools.water(Vector2i.ZERO) and _changes == changes_before, "Saturated no-op emits no change")
	_check(not tools.water(Vector2i(2, 0)) and not tools.fertilize(Vector2i(-1, 0)), "No-soil and out-of-bounds rejected")
	tools.water_infusion_amount = -0.1
	_check(not tools.water(Vector2i.ZERO) and _changes == changes_before, "Invalid tool configuration rejected without mutation")
	tools.free()
	turns.free()
	weather.free()
	farming.free()
	# Fresh saved scene: service references and real HUD input.
	root.size = Vector2i(1280, 720)
	var scene: FieldPrototypePresenter = (load("res://field_prototype.tscn") as PackedScene).instantiate() as FieldPrototypePresenter
	GameplayFixture.prepare(scene, true)
	scene.turn_controller.weather_manager.fluctuations_enabled = false
	scene.turn_controller.weather_manager.rainfall_per_turn = 0.02
	scene.turn_controller.weather_manager.evaporation_per_turn = 0.02
	root.add_child(scene)
	GameplayFixture.start(scene)
	for frame: int in range(5):
		await process_frame
	_check(scene.soil_tool_controller != null and scene.turn_controller.weather_manager != null, "Saved services wired")
	_check(scene.water_button != null and scene.fertilize_button != null, "Saved tool buttons wired")
	var idle_before: Variant = CycleChecks.state(scene.farming_controller.get_grid_snapshot())
	for frame: int in range(3):
		await process_frame
	_check(scene.turn_controller.turn_index == 0 and CycleChecks.state(scene.farming_controller.get_grid_snapshot()) == idle_before, "Idle frames never advance weather")
	# Balanced defaults are a confirmed weather tick, not a missing invocation.
	_click(scene.next_turn_button.get_global_rect().get_center())
	_check(scene.turn_controller.turn_index == 1 and scene.turn_controller.weather_manager.last_moisture_summary.contains("No net change"), "Native balanced turn reports weather invocation")
	_check(is_equal_approx(scene.farming_controller.get_grid_snapshot().get_cell(Vector2i.ZERO).soil.moisture, 0.5), "Balanced defaults preserve moisture intentionally")
	var target: Vector2i = Vector2i.ZERO
	var point: Vector2 = scene.world_view.terrain_layer.get_global_transform_with_canvas() * scene.world_view.terrain_layer.map_to_local(target)
	_click(scene.water_button.get_global_rect().get_center())
	_click(point)
	_check(QueueDriver.finish(scene), "Water queue completes")
	_check(is_equal_approx(scene.farming_controller.get_grid_snapshot().get_cell(target).soil.moisture, 0.6), "Native Water button and tile action")
	_click(scene.fertilize_button.get_global_rect().get_center())
	_click(point)
	_check(QueueDriver.finish(scene), "Fertilize queue completes")
	_check(is_equal_approx(scene.farming_controller.get_grid_snapshot().get_cell(target).soil.nitrogen, 0.6), "Native Fertilize button and tile action")
	scene.turn_controller.weather_manager.rainfall_per_turn = 0.1
	scene.turn_controller.weather_manager.evaporation_per_turn = 0.0
	_click(scene.next_turn_button.get_global_rect().get_center())
	_check(scene.turn_controller.turn_index == 2 and is_equal_approx(scene.farming_controller.get_grid_snapshot().get_cell(target).soil.moisture, 0.7), "Native Next Turn invokes configured weather")
	_check(scene.turn_controller.weather_manager.last_moisture_summary.contains("Weather turn 2:"), "Wetting diagnostic matches committed clock")
	scene.turn_controller.weather_manager.rainfall_per_turn = 0.0
	scene.turn_controller.weather_manager.evaporation_per_turn = 0.05
	_click(scene.next_turn_button.get_global_rect().get_center())
	_check(scene.turn_controller.turn_index == 3 and is_equal_approx(scene.farming_controller.get_grid_snapshot().get_cell(target).soil.moisture, 0.65), "Native Next Turn also invokes drying settings")
	# Keep the inspector open across a weather commit and verify its displayed value.
	scene._enter_inspect_mode()
	scene._on_cell_clicked(target)
	_check(scene.tile_inspector.macronutrients_label.text.contains("Soil moisture: 65.0%"), "Inspector displays current moisture")
	_click(scene.next_turn_button.get_global_rect().get_center())
	_check(scene.tile_inspector.macronutrients_label.text.contains("Soil moisture: 60.0%"), "Inspector refreshes committed weather moisture")
	scene._on_inspector_closed()
	# Fence/null-soil lifecycle through the real queue and walker, R3/R4.
	var fence: FieldAction = FieldAction.new()
	fence.kind = SimulationEnums.FieldActionKind.FENCE
	fence.target = target
	var fence_clock: int = scene.turn_controller.turn_index
	_check(scene.farming_controller.enqueue_action(fence), "Queue fence for weather lifecycle")
	var queued_before: Variant = CycleChecks.state(scene.farming_controller.get_grid_snapshot())
	_check(not scene.turn_controller.advance_turn(), "Pending fence rejects weather turn")
	_check(scene.turn_controller.turn_index == fence_clock and CycleChecks.state(scene.farming_controller.get_grid_snapshot()) == queued_before, "Pending queue rejection preserves field and phase")
	_check(QueueDriver.finish(scene), "Fence walker completes")
	_check(scene.turn_controller.turn_index == fence_clock, "Fence action does not advance weather")
	var neighbor: Vector2i = Vector2i(1, 0)
	var neighbor_before: float = scene.farming_controller.get_grid_snapshot().get_cell(neighbor).soil.moisture
	_click(scene.next_turn_button.get_global_rect().get_center())
	var fenced: FieldCellState = scene.farming_controller.get_grid_snapshot().get_cell(target)
	_check(fenced.has_fence and fenced.soil == null, "Weather preserves fenced null-soil cell")
	_check(absf(scene.farming_controller.get_grid_snapshot().get_cell(neighbor).soil.moisture - (neighbor_before - 0.05)) <= 0.000001, "Neighbor soil still receives weather beside fence")
	var remove: FieldAction = FieldAction.new()
	remove.kind = SimulationEnums.FieldActionKind.REMOVE_FENCE
	remove.target = target
	_check(scene.farming_controller.enqueue_action(remove) and QueueDriver.finish(scene), "Remove fence through queue")
	_click(scene.next_turn_button.get_global_rect().get_center())
	fenced = scene.farming_controller.get_grid_snapshot().get_cell(target)
	_check(not fenced.has_fence and fenced.soil == null, "Unfenced grass stays soil-free after weather")
	var dig: FieldAction = FieldAction.new()
	dig.kind = SimulationEnums.FieldActionKind.DIG_GRASS
	dig.target = target
	_check(scene.farming_controller.enqueue_action(dig) and QueueDriver.finish(scene), "Dig restores soil through queue")
	var dug_moisture: float = scene.farming_controller.get_grid_snapshot().get_cell(target).soil.moisture
	_click(scene.next_turn_button.get_global_rect().get_center())
	_check(absf(scene.farming_controller.get_grid_snapshot().get_cell(target).soil.moisture - (dug_moisture - 0.05)) <= 0.000001, "Restored soil receives weather on next turn")
	scene.queue_free()
	await process_frame
	if _failures.is_empty():
		print("WEATHER_SOIL_TOOLS_PASS")
		quit(0)
	else:
		for failure: String in _failures:
			printerr("FAIL: " + failure)
		quit(1)

func _click(screen_pos: Vector2) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = screen_pos
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate() as InputEventMouseButton
	event.pressed = false
	root.push_input(event, true)

func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)
