class_name TransmissionModifierProfile
extends Resource
## Optional phenomenological responses; defaults are uncalibrated and disabled.
## Caps are inverse simulation-time units, not probabilities.

@export var temperature_enabled: bool = false
@export var optimal_temperature_min: float = 20.0
@export var optimal_temperature_max: float = 30.0
@export var temperature_falloff_celsius: float = 10.0
@export var minimum_weather_multiplier: float = 0.1
@export var maximum_weather_multiplier: float = 2.0
@export var humidity_reference: float = 0.5
@export var humidity_sensitivity: float = 0.0
@export var nitrogen_excess_strength: float = 0.0
@export var potassium_protection_strength: float = 0.0
@export var potassium_falloff: float = 0.2
@export var maximum_effective_beta: float = 1000000.0
@export var maximum_hazard: float = 1000000.0

func validate() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if not is_finite(optimal_temperature_min):
		errors.append("optimal_temperature_min must be finite.")
	if not is_finite(optimal_temperature_max):
		errors.append("optimal_temperature_max must be finite.")
	if not is_finite(temperature_falloff_celsius):
		errors.append("temperature_falloff_celsius must be finite.")
	if not is_finite(minimum_weather_multiplier):
		errors.append("minimum_weather_multiplier must be finite.")
	if not is_finite(maximum_weather_multiplier):
		errors.append("maximum_weather_multiplier must be finite.")
	if not is_finite(humidity_reference):
		errors.append("humidity_reference must be finite.")
	if not is_finite(humidity_sensitivity):
		errors.append("humidity_sensitivity must be finite.")
	if not is_finite(nitrogen_excess_strength):
		errors.append("nitrogen_excess_strength must be finite.")
	if not is_finite(potassium_protection_strength):
		errors.append("potassium_protection_strength must be finite.")
	if not is_finite(potassium_falloff):
		errors.append("potassium_falloff must be finite.")
	if not is_finite(maximum_effective_beta):
		errors.append("maximum_effective_beta must be finite.")
	if not is_finite(maximum_hazard):
		errors.append("maximum_hazard must be finite.")
	if optimal_temperature_min < -273.15 or optimal_temperature_max < optimal_temperature_min:
		errors.append("Temperature interval must be ordered and above absolute zero.")
	if temperature_falloff_celsius <= 0.0 or potassium_falloff <= 0.0:
		errors.append("Falloff widths must be positive.")
	if minimum_weather_multiplier < 0.0 or minimum_weather_multiplier > 1.0 or maximum_weather_multiplier < 1.0:
		errors.append("Weather bounds must contain 1; minimum must be nonnegative.")
	if humidity_reference < 0.0 or humidity_reference >= 1.0:
		errors.append("humidity_reference must be in [0,1).")
	if humidity_sensitivity < 0.0 or humidity_sensitivity > 1.0:
		errors.append("humidity_sensitivity must be in [0,1].")
	if nitrogen_excess_strength < 0.0 or nitrogen_excess_strength > 1.0:
		errors.append("nitrogen_excess_strength must be in [0,1].")
	if potassium_protection_strength < 0.0 or potassium_protection_strength > 1.0:
		errors.append("potassium_protection_strength must be in [0,1].")
	if maximum_effective_beta <= 0.0 or maximum_hazard <= 0.0:
		errors.append("Rate caps must be positive.")
	return errors


func copy() -> TransmissionModifierProfile:
	var result: TransmissionModifierProfile = TransmissionModifierProfile.new()
	result.temperature_enabled = temperature_enabled
	result.optimal_temperature_min = optimal_temperature_min
	result.optimal_temperature_max = optimal_temperature_max
	result.temperature_falloff_celsius = temperature_falloff_celsius
	result.minimum_weather_multiplier = minimum_weather_multiplier
	result.maximum_weather_multiplier = maximum_weather_multiplier
	result.humidity_reference = humidity_reference
	result.humidity_sensitivity = humidity_sensitivity
	result.nitrogen_excess_strength = nitrogen_excess_strength
	result.potassium_protection_strength = potassium_protection_strength
	result.potassium_falloff = potassium_falloff
	result.maximum_effective_beta = maximum_effective_beta
	result.maximum_hazard = maximum_hazard
	return result
