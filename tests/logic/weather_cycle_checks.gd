extends RefCounted
## Supplemental R1-R8 checks invoked by the registered weather_soil_tools_test.
## See docs/WEATHER_CYCLE_VERIFICATION.md for scenario-to-function mapping.

const EPSILON: float = 0.000001
var failures: PackedStringArray = PackedStringArray()

class RejectingSimulation:
	extends SimulationController
	var reject: bool = true
	func process_turn(grid: FieldGridState, diseases: DiseaseDatabase) -> bool:
		if reject:
			rng.randf()
			weather_cap_count += 1
			beta_cap_count += 2
			hazard_cap_count += 3
			grid.get_cell(Vector2i.ZERO).soil.nitrogen = 0.1
			last_error = "Deliberate failure after weather and growth"
			return false
		return super.process_turn(grid, diseases)

class RejectingActivation:
	extends DiseaseActivationController
	var reject: bool = true
	func evaluate(grid: FieldGridState, diseases: DiseaseDatabase, completed_turn: int, active_filter: int = -1, allow_introduction: bool = true) -> Result:
		var result: Result = super.evaluate(grid, diseases, completed_turn, active_filter, allow_introduction)
		if reject:
			result.errors.append("Deliberate failure after activation proposal")
		return result

func run() -> PackedStringArray:
	_cycle_examples()
	_moisture_and_isolation()
	_validation()
	_growth_order()
	_lifecycle_and_rollback()
	_diagnostics()
	return failures

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)

func _near(actual: float, expected: float, label: String) -> void:
	_check(is_finite(actual) and absf(actual - expected) <= EPSILON, "%s: expected %.6f, got %.6f" % [label, expected, actual])

func _grid(moisture: float = 0.5) -> FieldGridState:
	var grid: FieldGridState = FieldGridState.new()
	_check(grid.initialize(2, 1, AbioticState.new()), "Initialize numeric fixture")
	for x: int in range(2):
		var cell: FieldCellState = grid.get_cell(Vector2i(x, 0))
		cell.terrain_type = SimulationEnums.TerrainType.DRY_SOIL
		cell.soil = SoilState.new()
		cell.soil.moisture = moisture
	return grid

func _cycle(weather: WeatherManager) -> void:
	weather.debug_moisture_updates = false
	weather.fluctuations_enabled = true
	weather.cycle_length_turns = 4
	weather.temperature_amplitude = 5.0
	weather.rainfall_amplitude = 0.02

func _moisture(grid: FieldGridState) -> float:
	return grid.get_cell(Vector2i.ZERO).soil.moisture

# Recursively compare all script-defined runtime fields, including nested soil,
# compartments, fences, abiotic state and activation history; no identity checks.
static func state(value: Variant) -> Variant:
	if value is Object:
		var result: Dictionary = {}
		for property: Dictionary in value.get_property_list():
			if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
				result[property.name] = state(value.get(property.name))
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value:
			result.append(state(item))
		return result
	return value

func _cycle_examples() -> void:
	var weather: WeatherManager = WeatherManager.new()
	_cycle(weather)
	var expected: Array[float] = [0.5, 0.518, 0.5, 0.482, 0.5, 0.518]
	for index: int in range(expected.size()):
		var grid: FieldGridState = _grid()
		_check(weather.apply_to_grid(grid, index), "Cycle phase %d succeeds" % index)
		_near(_moisture(grid), expected[index], "Cycle phase %d" % index)
	# Isolate rainfall from evaporation, so compensating errors cannot pass.
	weather.evaporation_per_turn = 0.0
	for index: int in range(4):
		var grid: FieldGridState = _grid()
		_check(weather.apply_to_grid(grid, index), "Rain-only cycle succeeds")
		_near(_moisture(grid), [0.52, 0.54, 0.52, 0.5][index], "Rain-only phase %d" % index)
	weather.evaporation_per_turn = 0.02
	weather.rainfall_moisture_scale = 0.0
	for index: int in range(4):
		var grid: FieldGridState = _grid()
		_check(weather.apply_to_grid(grid, index), "Temperature-only cycle succeeds")
		_near(_moisture(grid), [0.480, 0.478, 0.480, 0.482][index], "Temperature-only phase %d" % index)
	weather.rainfall_moisture_scale = 1.0
	var cumulative: FieldGridState = _grid()
	for index: int in range(6):
		_check(weather.apply_to_grid(cumulative, index), "Sequential cycle succeeds")
		_near(_moisture(cumulative), [0.5, 0.518, 0.518, 0.5, 0.5, 0.518][index], "Sequential phase %d" % index)
	weather.fluctuations_enabled = false
	var baseline: FieldGridState = _grid()
	_check(weather.apply_to_grid(baseline, 1), "Disabled fluctuations accepted")
	_near(_moisture(baseline), 0.5, "Disabled fluctuations ignore nonzero amplitudes")
	weather.fluctuations_enabled = true
	weather.cycle_length_turns = 1
	for index: int in range(3):
		_check(weather.apply_to_grid(baseline, index), "One-turn cycle accepted")
		_near(_moisture(baseline), 0.5, "One-turn cycle baseline")
	weather.cycle_length_turns = 4
	weather.temperature_amplitude = 0.0
	weather.evaporation_per_turn = 0.0
	weather.rainfall_per_turn = 0.02
	weather.rainfall_amplitude = 0.1
	baseline = _grid(0.0)
	_check(weather.apply_to_grid(baseline, 3), "Negative rain clamped")
	_near(_moisture(baseline), 0.0, "Rain lower bound")
	weather.rainfall_per_turn = 0.9
	weather.rainfall_amplitude = 0.2
	weather.rainfall_moisture_scale = 0.1
	_check(weather.apply_to_grid(baseline, 1), "Excess rain clamped")
	_near(_moisture(baseline), 0.1, "Rain upper bound independent of moisture saturation")
	weather.free()

func _moisture_and_isolation() -> void:
	var weather: WeatherManager = WeatherManager.new()
	for example: Array in [[0.5, 0.1, 0.02, 0.58], [0.5, 0.0, 0.05, 0.45], [0.95, 0.1, 0.0, 1.0], [0.03, 0.0, 0.05, 0.0]]:
		var grid: FieldGridState = _grid(example[0])
		weather.rainfall_per_turn = example[1]
		weather.evaporation_per_turn = example[2]
		_check(weather.apply_to_grid(grid, 0), "Moisture example succeeds")
		_near(_moisture(grid), example[3], "Moisture example %s" % str(example))
	weather.base_temperature_celsius = 35.0
	weather.ambient_humidity = 0.3
	weather.rainfall_per_turn = 0.0
	weather.evaporation_per_turn = 0.02
	var warm: FieldGridState = _grid()
	_check(weather.apply_to_grid(warm, 0), "Warm/dry example succeeds")
	_near(_moisture(warm), 0.4712, "Warm/dry example")
	# Independent bounds: temperature factor 1.2 capped at 1, humidity 1.2 capped at 1.
	weather.maximum_evaporation_factor = 1.0
	warm = _grid()
	_check(weather.apply_to_grid(warm, 0), "Factor upper cap succeeds")
	_near(_moisture(warm), 0.48, "Independent upper factor caps")
	weather.base_temperature_celsius = -100.0
	weather.ambient_humidity = 1.0
	weather.minimum_evaporation_factor = 0.8
	warm = _grid()
	_check(weather.apply_to_grid(warm, 0), "Factor lower cap succeeds")
	_near(_moisture(warm), 0.4872, "Independent lower factor caps")
	weather.free()
	weather = WeatherManager.new()
	weather.rainfall_per_turn = 0.1
	weather.evaporation_per_turn = 0.0
	var mixed: FieldGridState = FieldGridState.new()
	_check(mixed.initialize(4, 1, AbioticState.new()), "Mixed fixture initializes")
	for x: int in range(3):
		var cell: FieldCellState = mixed.get_cell(Vector2i(x, 0))
		cell.soil = SoilState.new()
		cell.terrain_type = SimulationEnums.TerrainType.PADDY_MUD if x == 2 else SimulationEnums.TerrainType.DRY_SOIL
		cell.has_crop = x > 0
		cell.crop_type = SimulationEnums.CropType.RICE if x == 2 else SimulationEnums.CropType.CORN
		cell.reset_crop_state()
	var before: FieldGridState = mixed.copy()
	_check(weather.apply_to_grid(mixed, 0), "Mixed planted and empty soil succeeds")
	for x: int in range(3):
		_near(mixed.get_cell(Vector2i(x, 0)).soil.moisture, 0.6, "Mixed soil tile %d" % x)
		mixed.get_cell(Vector2i(x, 0)).soil.moisture = before.get_cell(Vector2i(x, 0)).soil.moisture
	_check(state(mixed) == state(before), "Weather preserves all non-moisture fields and null soil")
	weather.free()

func _validation() -> void:
	var weather: WeatherManager = WeatherManager.new()
	var grid: FieldGridState = _grid()
	var before: Variant = state(grid)
	for key: String in ["rainfall_per_turn", "evaporation_per_turn", "ambient_humidity", "humidity_reference", "rainfall_amplitude"]:
		var original: Variant = weather.get(key)
		for bad: float in [-0.01, 1.01, NAN, INF]:
			weather.set(key, bad)
			_check(not weather.apply_to_grid(grid, 0) and weather.last_error.contains(key), "Reject invalid %s = %s" % [key, bad])
			_check(state(grid) == before, "Invalid normalized setting preserves entire grid")
		weather.set(key, original)
	for key: String in ["rainfall_moisture_scale", "temperature_evaporation_sensitivity", "humidity_evaporation_sensitivity", "minimum_evaporation_factor", "maximum_evaporation_factor", "temperature_amplitude"]:
		var original: Variant = weather.get(key)
		for bad: float in [-0.1, NAN, INF]:
			weather.set(key, bad)
			_check(not weather.apply_to_grid(grid, 0) and weather.last_error.contains(key), "Reject invalid nonnegative %s" % key)
		weather.set(key, original)
	for key: String in ["base_temperature_celsius", "temperature_reference_celsius"]:
		var original: Variant = weather.get(key)
		for bad: float in [-274.0, NAN, INF]:
			weather.set(key, bad)
			_check(not weather.apply_to_grid(grid, 0) and weather.last_error.contains(key), "Reject invalid temperature %s" % key)
		weather.set(key, original)
	for length: int in [0, -1]:
		weather.cycle_length_turns = length
		_check(not weather.apply_to_grid(grid, 0) and weather.last_error.contains("positive"), "Reject nonpositive cycle %d" % length)
	weather.cycle_length_turns = 4
	weather.minimum_evaporation_factor = 4.0
	_check(not weather.apply_to_grid(grid, 0) and weather.last_error.contains("reversed"), "Reject reversed caps")
	weather.minimum_evaporation_factor = 0.0
	weather.fluctuations_enabled = true
	weather.base_temperature_celsius = -270.0
	weather.temperature_amplitude = 5.0
	_check(not weather.apply_to_grid(grid, 0) and weather.last_error.contains("absolute zero"), "Reject cycle below absolute zero")
	weather.base_temperature_celsius = 25.0
	for source: WeatherManager.SourceMode in [WeatherManager.SourceMode.CLIMATE_RESOURCE, WeatherManager.SourceMode.CSV]:
		weather.source_mode = source
		_check(not weather.apply_to_grid(grid, 0) and weather.last_error.contains("not implemented"), "Reject external source %d" % source)
	weather.source_mode = WeatherManager.SourceMode.INSPECTOR
	_check(not weather.apply_to_grid(null, 0), "Reject missing grid")
	_check(not weather.apply_to_grid(FieldGridState.new(), 0), "Reject invalid grid")
	_check(not weather.apply_to_grid(grid, -1), "Reject negative phase")
	_check(state(grid) == before, "Every validation failure preserves all fields")
	# Finite settings can still overflow intermediate arithmetic.
	weather.base_temperature_celsius = 1.0e308
	weather.temperature_evaporation_sensitivity = 1.0e308
	_check(not weather.apply_to_grid(grid, 0) and weather.last_error.contains("overflow"), "Reject factor overflow")
	weather.base_temperature_celsius = 25.0
	weather.temperature_evaporation_sensitivity = 0.02
	weather.minimum_evaporation_factor = 1.0e200
	weather.maximum_evaporation_factor = 1.0e200
	var grass: FieldGridState = FieldGridState.new()
	_check(grass.initialize(1, 1, AbioticState.new()), "Initialize soil-free overflow fixture")
	_check(not weather.apply_to_grid(grass, 0) and weather.last_error.contains("overflow"), "Reject evaporation overflow even without soil")
	_check(not weather.apply_to_grid(grid, 0) and state(grid) == before, "Overflow does not partially write soil")
	weather.enabled = false
	weather.source_mode = WeatherManager.SourceMode.CSV
	weather.cycle_length_turns = 0
	weather.rainfall_per_turn = NAN
	_check(weather.apply_to_grid(grid, 0) and state(grid) == before, "Disabled weather bypasses bad configuration")
	_check(not weather.apply_to_grid(null, 0), "Disabled weather still rejects null grid")
	_check(not weather.apply_to_grid(FieldGridState.new(), 0), "Disabled weather still rejects invalid grid")
	_check(not weather.apply_to_grid(grid, -1), "Disabled weather still rejects negative phase")
	weather.free()

func _growth_order() -> void:
	var farming: FarmingController = FarmingController.new()
	farming.crop_database = (load("res://src/data/databases/crop_database.tres") as CropDatabase).duplicate(true) as CropDatabase
	var crop: CropData = farming.crop_database.get_crop(SimulationEnums.CropType.RICE)
	crop.growth_profile.moisture_minimum = 0.6
	crop.growth_profile.moisture_falloff = 0.1
	farming.terrain_database = load("res://src/data/databases/terrain_database.tres") as TerrainDatabase
	farming.initial_soil = SoilState.new()
	farming.initial_abiotic = AbioticState.new()
	farming.field_size = Vector2i(1, 1)
	farming.terrain_bands = [SimulationEnums.TerrainType.PADDY_MUD]
	_check(farming.initialize_field() and farming.try_plant(Vector2i.ZERO, SimulationEnums.CropType.RICE), "Initialize growth-order fixture")
	var weather: WeatherManager = WeatherManager.new()
	weather.debug_moisture_updates = false
	weather.rainfall_per_turn = 0.1
	weather.evaporation_per_turn = 0.0
	var turns: TurnController = TurnController.new()
	turns.farming_controller = farming
	turns.weather_manager = weather
	_check(turns.advance_turn(), "Weather-before-growth turn succeeds")
	var cell: FieldCellState = farming.get_grid_snapshot().get_cell(Vector2i.ZERO)
	_near(cell.soil.moisture, 0.6, "Growth receives wetting to 0.6")
	_check(cell.growth_elapsed_ticks == 1 and cell.vitality == 1.0, "Growth uses new moisture rather than old dry stress")
	turns.free()
	weather.free()
	farming.free()

func _lifecycle_and_rollback() -> void:
	var farming: FarmingController = FarmingController.new()
	farming.crop_database = load("res://src/data/databases/crop_database.tres") as CropDatabase
	farming.terrain_database = load("res://src/data/databases/terrain_database.tres") as TerrainDatabase
	farming.initial_soil = SoilState.new()
	farming.initial_abiotic = AbioticState.new()
	farming.field_size = Vector2i(2, 1)
	farming.terrain_bands = [SimulationEnums.TerrainType.PADDY_MUD]
	_check(farming.initialize_field(), "Initialize lifecycle fixture")
	_check(farming.try_plant(Vector2i.ZERO, SimulationEnums.CropType.RICE), "Plant rollback fixture")
	var weather: WeatherManager = WeatherManager.new()
	_cycle(weather)
	var turns: TurnController = TurnController.new()
	turns.farming_controller = farming
	turns.weather_manager = weather
	turns.disease_database = load("res://src/data/databases/default_disease_database.tres") as DiseaseDatabase
	var activation: RejectingActivation = RejectingActivation.new()
	activation.policy = DiseaseActivationPolicy.new()
	activation.policy.first_eligible_turn = 1
	activation.policy.chance_per_eligible_turn = 1.0
	activation.debug_introductions = false
	turns.disease_activation_controller = activation
	var simulation: RejectingSimulation = RejectingSimulation.new()
	turns.simulation_controller = simulation
	turns.turn_index = 1
	var events: Array[int] = [0]
	turns.turn_completed.connect(func(_index: int) -> void: events[0] += 1)
	var before: Variant = state(farming.get_grid_snapshot())
	var activation_before: Variant = state(activation.get_state_snapshot())
	var rng_before: int = simulation.rng.state
	var counters: Vector3i = Vector3i(simulation.weather_cap_count, simulation.beta_cap_count, simulation.hazard_cap_count)
	var summary: String = weather.last_moisture_summary
	_check(not turns.advance_turn(), "Reject after weather/growth and RNG consumption")
	_check(state(farming.get_grid_snapshot()) == before, "Full grid rollback after simulation failure")
	_check(simulation.rng.state == rng_before and Vector3i(simulation.weather_cap_count, simulation.beta_cap_count, simulation.hazard_cap_count) == counters, "Restore consumed RNG and changed counters")
	_check(state(activation.get_state_snapshot()) == activation_before, "No activation commit after simulation failure")
	_check(turns.turn_index == 1 and events[0] == 0 and weather.last_moisture_summary == summary, "Failure preserves phase, events and summary")
	# Also fail after a real activation proposal has selected and drawn an infection.
	simulation.reject = false
	_check(not turns.advance_turn(), "Reject after activation proposal")
	_check(state(farming.get_grid_snapshot()) == before and state(activation.get_state_snapshot()) == activation_before, "Activation proposal is discarded with entire grid")
	_check(simulation.rng.state == rng_before and Vector3i(simulation.weather_cap_count, simulation.beta_cap_count, simulation.hazard_cap_count) == counters, "Later failure restores simulation transaction")
	_check(turns.turn_index == 1 and events[0] == 0 and weather.last_moisture_summary == summary, "Later failure has no successful notification")
	activation.reject = false
	_check(turns.advance_turn(), "Retry same nonzero phase succeeds")
	_near(_moisture(farming.get_grid_snapshot()), 0.518, "Retry uses phase one")
	_check(turns.turn_index == 2 and events[0] == 1 and activation.get_state_snapshot().introductions_committed == 1, "Retry commits exactly once")
	# Session reset and re-enabling derive phase only from the shared clock.
	_check(farming.initialize_field(), "Reset field")
	turns.reset_clock()
	activation.policy.enabled = false
	_check(turns.turn_index == 0 and activation.get_state_snapshot().introductions_committed == 0, "Reset clock and activation")
	_check(turns.advance_turn(), "First new-session turn succeeds")
	_near(_moisture(farming.get_grid_snapshot()), 0.5, "New session starts at phase zero")
	weather.enabled = false
	_check(turns.advance_turn() and turns.advance_turn(), "Disabled weather still advances two turns")
	_near(_moisture(farming.get_grid_snapshot()), 0.5, "Disabled moisture unchanged")
	weather.enabled = true
	_check(turns.advance_turn(), "Re-enable at current phase")
	_near(_moisture(farming.get_grid_snapshot()), 0.482, "Re-enable uses phase three, not saved phase one")
	weather.fluctuations_enabled = false
	weather.rainfall_per_turn = 0.1
	_near(_moisture(farming.get_grid_snapshot()), 0.482, "Configuration edit is not an immediate mutation")
	_check(turns.advance_turn(), "Edited rates commit next turn")
	_near(_moisture(farming.get_grid_snapshot()), 0.562, "Edited rates contribute once")
	# Full-turn configuration rejection, not only direct WeatherManager calls.
	before = state(farming.get_grid_snapshot())
	var clock: int = turns.turn_index
	for length: int in [0, -1]:
		weather.cycle_length_turns = length
		_check(not turns.advance_turn() and turns.last_error.contains("positive"), "Invalid cycle rejects complete turn")
		_check(turns.turn_index == clock and state(farming.get_grid_snapshot()) == before, "Rejected cycle is atomic")
	weather.cycle_length_turns = 4
	for source: WeatherManager.SourceMode in [WeatherManager.SourceMode.CLIMATE_RESOURCE, WeatherManager.SourceMode.CSV]:
		weather.source_mode = source
		_check(not turns.advance_turn() and turns.last_error.contains("not implemented"), "External mode rejects complete turn")
		_check(turns.turn_index == clock and state(farming.get_grid_snapshot()) == before, "Rejected source is atomic")
	weather.source_mode = WeatherManager.SourceMode.INSPECTOR
	var game: GameStateManager = GameStateManager.new()
	turns.game_state_manager = game
	_check(not turns.advance_turn() and turns.turn_index == clock, "Menu rejects turns")
	game.start_game()
	game.turn_limit = clock + 1
	# A nested request from a completion observer must not consume another phase.
	var nested: Array[bool] = []
	turns.turn_completed.connect(func(_index: int) -> void: nested.append(turns.advance_turn()))
	game.turn_limit = clock + 2
	_check(turns.advance_turn() and nested == [false], "Reentrant request while playing is rejected")
	nested.clear()
	_check(turns.advance_turn(), "Terminal turn itself commits")
	_check(nested == [false] and game.current_state == GameStateManager.State.GAME_OVER, "Nested request and terminal state guarded")
	before = state(farming.get_grid_snapshot())
	_check(not turns.advance_turn() and turns.turn_index == clock + 2 and state(farming.get_grid_snapshot()) == before, "No weather after game over")
	game.free()
	turns.free()
	activation.free()
	weather.free()
	farming.free()

func _diagnostics() -> void:
	print("WEATHER_SILENT_BEGIN")
	var weather: WeatherManager = WeatherManager.new()
	weather.debug_moisture_updates = false
	var before: FieldGridState = _grid()
	weather.report_committed_moisture(before, before.copy(), 1)
	_check(weather.last_moisture_summary.contains("Weather turn 1: 0/2") and weather.last_moisture_summary.contains("0.5000 -> 0.5000") and weather.last_moisture_summary.contains("No net change"), "Balanced summary recorded with debug disabled")
	weather.enabled = false
	weather.report_committed_moisture(before, before.copy(), 2)
	_check(weather.last_moisture_summary.contains("Weather is disabled"), "Disabled summary is distinct")
	weather.enabled = true
	weather.rainfall_per_turn = 0.1
	weather.evaporation_per_turn = 0.0
	var after: FieldGridState = before.copy()
	_check(weather.apply_to_grid(after, 2), "Diagnostic wetting succeeds")
	weather.report_committed_moisture(before, after, 3)
	_check(weather.last_moisture_summary.contains("Weather turn 3: 2/2") and weather.last_moisture_summary.contains("0.5000 -> 0.6000"), "Changed count and means reflect commit")
	var grass: FieldGridState = FieldGridState.new()
	_check(grass.initialize(1, 1, AbioticState.new()), "Diagnostic grass fixture initializes")
	weather.report_committed_moisture(grass, grass.copy(), 4)
	_check(weather.last_moisture_summary.contains("0/0") and weather.last_moisture_summary.contains("0.0000 -> 0.0000"), "Zero-soil summary remains finite")
	print("WEATHER_SILENT_END")
	print("WEATHER_DEBUG_BEGIN")
	weather.debug_moisture_updates = true
	weather.report_committed_moisture(before, after, 3)
	print("WEATHER_DEBUG_END")
	weather.free()
