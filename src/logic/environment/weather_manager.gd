class_name WeatherManager
extends Node
## Stateless turn-indexed crop hydration service. Operates on a staged grid only.
## Temperature/humidity here tune evaporation; they do not overwrite AbioticState.

enum SourceMode { INSPECTOR, CLIMATE_RESOURCE, CSV }
@export var enabled: bool = true
@export var debug_moisture_updates: bool = true
@export_group("Weather baselines")
@export var base_temperature_celsius: float = 25.0
@export_range(0.0, 1.0) var rainfall_per_turn: float = 0.02
@export_range(0.0, 1.0) var evaporation_per_turn: float = 0.02
@export_range(0.0, 1.0) var ambient_humidity: float = 0.5
@export_range(0.0, 10.0) var rainfall_moisture_scale: float = 1.0
@export_group("Evaporation response")
@export var temperature_reference_celsius: float = 25.0
@export_range(0.0, 1.0) var temperature_evaporation_sensitivity: float = 0.02
@export_range(0.0, 1.0) var humidity_reference: float = 0.5
@export_range(0.0, 10.0) var humidity_evaporation_sensitivity: float = 1.0
@export_range(0.0, 10.0) var minimum_evaporation_factor: float = 0.0
@export_range(0.0, 10.0) var maximum_evaporation_factor: float = 3.0
@export_group("Deterministic fluctuations")
@export var fluctuations_enabled: bool = false
@export_range(0.0, 50.0) var temperature_amplitude: float = 0.0
@export_range(0.0, 1.0) var rainfall_amplitude: float = 0.0
@export_range(1, 365) var cycle_length_turns: int = 8
@export_group("Future climate source (hooks only)")
@export var source_mode: SourceMode = SourceMode.INSPECTOR
@export var climate_resource: Resource
@export_file("*.csv") var climate_csv_path: String = ""

var last_error: String = ""
var last_moisture_summary: String = ""

func validate_configuration() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if not enabled:
		return errors
	if source_mode != SourceMode.INSPECTOR:
		errors.append("External climate sources are not implemented. Select Inspector mode.")
	for key: StringName in [&"rainfall_per_turn", &"evaporation_per_turn", &"ambient_humidity", &"humidity_reference", &"rainfall_amplitude"]:
		var value: float = get(key)
		if not is_finite(value) or value < 0.0 or value > 1.0:
			errors.append("%s must be finite and in [0, 1]." % key)
	for key: StringName in [&"rainfall_moisture_scale", &"temperature_evaporation_sensitivity", &"humidity_evaporation_sensitivity", &"minimum_evaporation_factor", &"maximum_evaporation_factor", &"temperature_amplitude"]:
		var value: float = get(key)
		if not is_finite(value) or value < 0.0:
			errors.append("%s must be finite and nonnegative." % key)
	for key: StringName in [&"base_temperature_celsius", &"temperature_reference_celsius"]:
		var value: float = get(key)
		if not is_finite(value) or value < -273.15:
			errors.append("%s must be finite and at least -273.15." % key)
	if maximum_evaporation_factor < minimum_evaporation_factor:
		errors.append("Evaporation factor limits are reversed.")
	if cycle_length_turns < 1:
		errors.append("Weather cycle length must be positive.")
	if fluctuations_enabled and base_temperature_celsius - temperature_amplitude < -273.15:
		errors.append("Temperature fluctuation crosses absolute zero.")
	return errors

func apply_to_grid(staged_grid: FieldGridState, turn_index: int) -> bool:
	last_error = ""
	var errors: PackedStringArray = validate_configuration()
	if staged_grid == null or turn_index < 0:
		errors.append("A grid and nonnegative turn index are required.")
	elif not staged_grid.validate().is_empty():
		errors.append_array(staged_grid.validate())
	if not errors.is_empty():
		last_error = "\n".join(errors)
		return false
	if not enabled:
		return true
	var wave: float = sin(TAU * float(turn_index % cycle_length_turns) / float(cycle_length_turns)) if fluctuations_enabled else 0.0
	var temperature: float = base_temperature_celsius + wave * temperature_amplitude
	var rainfall: float = clampf(rainfall_per_turn + wave * rainfall_amplitude, 0.0, 1.0)
	var raw_temperature_factor: float = 1.0 + (temperature - temperature_reference_celsius) * temperature_evaporation_sensitivity
	var raw_humidity_factor: float = 1.0 + (humidity_reference - ambient_humidity) * humidity_evaporation_sensitivity
	if not is_finite(raw_temperature_factor) or not is_finite(raw_humidity_factor):
		last_error = "Evaporation response overflow. Reduce configured values."
		return false
	var temperature_factor: float = clampf(raw_temperature_factor, minimum_evaporation_factor, maximum_evaporation_factor)
	var humidity_factor: float = clampf(raw_humidity_factor, minimum_evaporation_factor, maximum_evaporation_factor)
	var evaporation: float = evaporation_per_turn * temperature_factor * humidity_factor
	var updates: Dictionary[Vector2i, float] = {}
	for y: int in range(staged_grid.height):
		for x: int in range(staged_grid.width):
			var coordinates: Vector2i = Vector2i(x, y)
			var cell: FieldCellState = staged_grid.get_cell(coordinates)
			if cell.soil == null:
				continue
			var next: float = SoilMoistureModel.next_moisture(cell.soil.moisture, rainfall, evaporation, rainfall_moisture_scale)
			if not is_finite(next):
				last_error = "Invalid moisture result. Reduce configured values."
				return false
			updates[coordinates] = next
	for coordinates: Vector2i in updates:
		staged_grid.get_cell(coordinates).soil.moisture = updates[coordinates]
	return true


## Called only after the complete turn succeeds, never for staged/rolled-back data.
func report_committed_moisture(before: FieldGridState, after: FieldGridState, completed_turn: int) -> void:
	var soil_count: int = 0
	var changed_count: int = 0
	var total_before: float = 0.0
	var total_after: float = 0.0
	for y: int in range(after.height):
		for x: int in range(after.width):
			var coordinates: Vector2i = Vector2i(x, y)
			var old_cell: FieldCellState = before.get_cell(coordinates)
			var new_cell: FieldCellState = after.get_cell(coordinates)
			if old_cell == null or old_cell.soil == null or new_cell == null or new_cell.soil == null:
				continue
			soil_count += 1
			total_before += old_cell.soil.moisture
			total_after += new_cell.soil.moisture
			if not is_equal_approx(old_cell.soil.moisture, new_cell.soil.moisture):
				changed_count += 1
	var denominator: float = float(maxi(1, soil_count))
	last_moisture_summary = "Weather turn %d: %d/%d soil tiles changed; mean moisture %.4f -> %.4f." % [completed_turn, changed_count, soil_count, total_before / denominator, total_after / denominator]
	if not enabled:
		last_moisture_summary += " Weather is disabled."
	elif changed_count == 0:
		last_moisture_summary += " No net change: check rainfall/evaporation balance or moisture bounds."
	if debug_moisture_updates:
		print(last_moisture_summary)
