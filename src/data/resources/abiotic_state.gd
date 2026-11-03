class_name AbioticState
extends Resource
## Passive field-wide environmental data for the initial prototype.
## Defaults are authoring placeholders, not recommended growing conditions.

## Normalized instantaneous light; this is not a measured irradiance unit.
@export_range(0.0, 1.0, 0.01) var light_intensity: float = 0.5

## Fractional relative humidity: 0.75 represents 75 percent.
@export_range(0.0, 1.0, 0.01) var relative_humidity: float = 0.5

## Kilopascals. The Inspector slider is a convenience, not a validity bound.
@export_range(80.0, 110.0, 0.1, "or_greater", "or_less")
var atmospheric_pressure_kpa: float = 101.325


## Reports invalid values without mutating this resource.
func validate() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	_validate_normalized("light_intensity", light_intensity, errors)
	_validate_normalized("relative_humidity", relative_humidity, errors)
	if is_nan(atmospheric_pressure_kpa) or is_inf(atmospheric_pressure_kpa):
		errors.append("atmospheric_pressure_kpa must be finite.")
	elif atmospheric_pressure_kpa <= 0.0:
		errors.append("atmospheric_pressure_kpa must be greater than 0.0; received %s." % atmospheric_pressure_kpa)
	return errors


## Copies all schema values, including invalid values, without sharing state.
func copy() -> AbioticState:
	var result: AbioticState = AbioticState.new()
	result.light_intensity = light_intensity
	result.relative_humidity = relative_humidity
	result.atmospheric_pressure_kpa = atmospheric_pressure_kpa
	return result


func _validate_normalized(
	property_name: String,
	value: float,
	errors: PackedStringArray
) -> void:
	if is_nan(value) or is_inf(value):
		errors.append("%s must be finite." % property_name)
	elif value < 0.0 or value > 1.0:
		errors.append("%s must be in [0.0, 1.0]; received %s." % [property_name, value])
