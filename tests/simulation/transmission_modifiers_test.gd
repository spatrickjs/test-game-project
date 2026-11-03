extends SceneTree

var failures: int = 0


func _initialize() -> void:
	var environment: AbioticState = AbioticState.new()
	var soil: SoilState = SoilState.new()
	var disease: DiseaseData = DiseaseData.new()
	disease.display_name = "Modifier test"
	disease.beta = 2.0
	var crop: CropData = CropData.new()
	crop.display_name = "Sugarcane"
	var n: NutrientRule = _rule(SimulationEnums.NutrientType.NITROGEN, 0.2, 0.6)
	var k: NutrientRule = _rule(SimulationEnums.NutrientType.POTASSIUM, 0.4, 0.6)
	crop.nutrient_requirement_rules.assign([n, k])
	var response: TransmissionModifiers.Result = TransmissionModifiers.evaluate(disease, environment, soil, crop, 3.0)
	check(response.hazard == 6.0 and response.weather == 1.0 and response.nutrient == 1.0, "Missing profile is neutral")
	var profile: TransmissionModifierProfile = TransmissionModifierProfile.new()
	disease.transmission_modifier_profile = profile
	response = TransmissionModifiers.evaluate(disease, environment, soil, crop, 3.0)
	check(response.hazard == 6.0, "Disabled profile is neutral")
	check(environment.temperature_celsius == 25.0 and environment.copy().temperature_celsius == 25.0, "Temperature default and copy")
	profile.temperature_enabled = true
	profile.optimal_temperature_min = 20.0
	profile.optimal_temperature_max = 30.0
	profile.temperature_falloff_celsius = 10.0
	for temperature: float in [20.0, 25.0, 30.0]:
		environment.temperature_celsius = temperature
		check(TransmissionModifiers.evaluate(disease, environment, soil, crop, 1.0).weather == 1.0, "Optimal inclusive temperature interval")
	for temperature: float in [15.0, 35.0]:
		environment.temperature_celsius = temperature
		check(is_equal_approx(TransmissionModifiers.evaluate(disease, environment, soil, crop, 1.0).weather, 0.55), "Symmetric linear temperature falloff")
	environment.temperature_celsius = 45.0
	check(is_equal_approx(TransmissionModifiers.evaluate(disease, environment, soil, crop, 1.0).weather, 0.1), "Temperature floor")
	environment.temperature_celsius = 25.0
	profile.humidity_sensitivity = 0.8
	for humidity: float in [0.0, 0.5]:
		environment.relative_humidity = humidity
		check(TransmissionModifiers.evaluate(disease, environment, soil, crop, 1.0).weather == 1.0, "Humidity below reference neutral")
	environment.relative_humidity = 1.0
	check(is_equal_approx(TransmissionModifiers.evaluate(disease, environment, soil, crop, 1.0).weather, 1.8), "Humidity upper endpoint")
	profile.maximum_weather_multiplier = 1.4
	response = TransmissionModifiers.evaluate(disease, environment, soil, crop, 1.0)
	check(response.weather == 1.4 and response.weather_capped, "Weather cap diagnostic")
	profile.humidity_sensitivity = 0.0
	profile.nitrogen_excess_strength = 0.25
	profile.potassium_protection_strength = 0.15
	soil.nitrogen = 0.6
	check(is_equal_approx(TransmissionModifiers.evaluate(disease, environment, soil, crop, 1.0).nutrient, 0.85), "N at threshold, optimal K")
	soil.nitrogen = 1.0
	soil.potassium = 0.0
	check(is_equal_approx(TransmissionModifiers.evaluate(disease, environment, soil, crop, 1.0).nutrient, 1.25), "Maximum nitrogen excess")
	soil.nitrogen = 0.6
	soil.potassium = 0.3
	check(is_equal_approx(TransmissionModifiers.evaluate(disease, environment, soil, crop, 1.0).nutrient, 0.925), "Smooth potassium half falloff")
	soil.potassium = 0.7
	check(is_equal_approx(TransmissionModifiers.evaluate(disease, environment, soil, crop, 1.0).nutrient, 0.925), "Potassium upper falloff")
	n.optimal_range.max_value = 1.0
	soil.nitrogen = 1.0
	soil.potassium = 0.0
	check(TransmissionModifiers.evaluate(disease, environment, soil, crop, 1.0).nutrient == 1.0, "N max=1 avoids division by zero")
	crop.nutrient_requirement_rules.clear()
	check(TransmissionModifiers.evaluate(disease, environment, soil, crop, 1.0).nutrient == 1.0, "Missing rules neutral")
	crop.nutrient_requirement_rules.assign([n, k])
	n.optimal_range.max_value = 0.6

	disease.beta = 1.0e308
	profile.maximum_effective_beta = 3.0
	profile.maximum_hazard = 4.0
	response = TransmissionModifiers.evaluate(disease, environment, soil, crop, 1.0e308)
	check(response.effective_beta == 3.0 and response.hazard == 4.0 and response.beta_capped and response.hazard_capped, "Overflow-safe independent caps")
	response = TransmissionModifiers.evaluate(disease, environment, soil, crop, 0.0)
	check(response.hazard == 0.0 and not response.hazard_capped, "Zero pressure cannot transmit")
	disease.beta = 1.0
	profile.maximum_effective_beta = 1.0
	soil.nitrogen = 0.6
	soil.potassium = 0.5
	profile.humidity_sensitivity = 0.2
	profile.maximum_weather_multiplier = 2.0
	response = TransmissionModifiers.evaluate(disease, environment, soil, crop, 1.0)
	check(is_equal_approx(response.effective_beta, 1.0), "Cap after complete product")
	profile.humidity_sensitivity = 0.1
	response = TransmissionModifiers.evaluate(disease, environment, soil, crop, 1.0)
	check(is_equal_approx(response.effective_beta, 0.935) and not response.beta_capped, "Protection included before cap")
	var copied: DiseaseData = disease.copy()
	copied.transmission_modifier_profile.humidity_sensitivity = 0.7
	check(profile.humidity_sensitivity == 0.1, "Deep-copy profile isolation")
	profile.temperature_falloff_celsius = 0.0
	check(not profile.validate().is_empty(), "Reject zero falloff")
	profile.temperature_falloff_celsius = 10.0
	profile.maximum_hazard = INF
	check(not disease.validate().is_empty(), "Reject nonfinite caps")
	profile.maximum_hazard = 4.0
	environment.temperature_celsius = NAN
	check(not environment.validate().is_empty(), "Reject invalid global temperature")
	environment.temperature_celsius = 25.0

	# Shared hazard drives all models with per-recipient N and K.
	var database: DiseaseDatabase = DiseaseDatabase.new()
	database.diseases.append(disease)
	var crops: CropDatabase = CropDatabase.new()
	crops.crops.append(crop)
	profile.maximum_effective_beta = 100.0
	profile.maximum_hazard = 100.0
	profile.humidity_sensitivity = 0.0
	for algorithm: int in [0, 1, 2]:
		var engine: SimulationController = SimulationController.new()
		engine.crop_database = crops
		engine.algorithm_override = algorithm
		engine.rng.seed = 92
		var other: SimulationController = SimulationController.new()
		other.crop_database = crops
		other.algorithm_override = algorithm
		other.rng.seed = 92
		var grid: FieldGridState = _grid()
		var duplicate: FieldGridState = grid.copy()
		var initial_source_n: float = grid.get_cell(Vector2i.ZERO).soil.nitrogen
		check(engine.process_turn(grid, database) and other.process_turn(duplicate, database), "Modifier model turn")
		var recipient: FieldCellState = grid.get_cell(Vector2i(1, 0))
		if algorithm != 2:
			var infection: float = recipient.exposed_fraction if algorithm == 1 else recipient.infected_fraction
			check(is_equal_approx(infection, 1.0 - exp(-1.25 * 0.85)), "Recipient-side modified flux in continuous models")
		check(grid.get_cell(Vector2i(2, 0)).susceptible_fraction == 1.0, "Modifiers preserve simultaneous updates")
		check(grid.get_cell(Vector2i.ZERO).soil.nitrogen == initial_source_n, "No soil mutation")
		for tick: int in range(10):
			check(engine.process_turn(grid, database) and other.process_turn(duplicate, database), "Repeated modified turns")
			for x: int in range(3):
				var cell: FieldCellState = grid.get_cell(Vector2i(x, 0))
				var sum: float = 0.0
				for value: float in CompartmentMath.fractions(cell):
					sum += value
				check(absf(sum - 1.0) < 1.0e-10 and cell.validate().is_empty(), "Modified conservation")
				check(CompartmentMath.fractions(cell) == CompartmentMath.fractions(duplicate.get_cell(Vector2i(x, 0))), "Seeded modifier reproducibility")
		profile.maximum_effective_beta = 0.1
		profile.maximum_hazard = 0.01
		check(engine.process_turn(grid, database) and engine.beta_cap_count > 0, "Controller exposes cap diagnostics")
		profile.maximum_effective_beta = 100.0
		profile.maximum_hazard = 100.0
	var missing_crop: SimulationController = SimulationController.new()
	check(not missing_crop.process_turn(_grid(), database), "Enabled nutrients require crop catalog")
	profile.nitrogen_excess_strength = 0.0
	profile.potassium_protection_strength = 0.0
	check(missing_crop.process_turn(_grid(), database), "Weather-only profile needs no crop catalog")
	profile.minimum_weather_multiplier = 0.0
	var grid: FieldGridState = _grid()
	grid.abiotic_state.temperature_celsius = 50.0
	check(missing_crop.process_turn(grid, database), "Zero weather floor supported")
	check(grid.get_cell(Vector2i(1, 0)).susceptible_fraction == 1.0, "Weather can suppress transmission completely")
	if failures == 0:
		print("TRANSMISSION_MODIFIERS_PASS")
	quit(0 if failures == 0 else 1)


func _rule(nutrient: SimulationEnums.NutrientType, low: float, high: float) -> NutrientRule:
	var rule: NutrientRule = NutrientRule.new()
	rule.nutrient = nutrient
	rule.optimal_range = FloatRange.new()
	rule.optimal_range.min_value = low
	rule.optimal_range.max_value = high
	return rule


func _grid() -> FieldGridState:
	var grid: FieldGridState = FieldGridState.new()
	grid.initialize(3, 1, AbioticState.new())
	for x: int in range(3):
		var cell: FieldCellState = grid.get_cell(Vector2i(x, 0))
		cell.terrain_type = SimulationEnums.TerrainType.DRY_SOIL
		cell.soil = SoilState.new()
		cell.has_crop = true
		cell.reset_crop_state()
		cell.soil.nitrogen = 1.0 if x == 1 else 0.0
	var source: FieldCellState = grid.get_cell(Vector2i.ZERO)
	source.has_active_disease = true
	CompartmentMath.set_one_hot(source, 2)
	return grid


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)
