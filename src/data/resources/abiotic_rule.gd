class_name AbioticRule
extends Resource
## Crop tolerance interval, or disease-favorable interval when owned by a disease.
## Disease pressure increases inside the interval; empty parent arrays are neutral.

@export var factor: SimulationEnums.AbioticFactor = SimulationEnums.AbioticFactor.RELATIVE_HUMIDITY
@export var optimal_range: FloatRange = null
@export_range(0.0, 1.0, 0.01) var weight: float = 1.0


func validate() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if not SimulationEnums.AbioticFactor.values().has(factor):
		errors.append("factor has an invalid identifier.")
	if is_nan(weight) or is_inf(weight):
		errors.append("weight must be finite.")
	elif weight < 0.0 or weight > 1.0:
		errors.append("weight must be in [0.0, 1.0].")
	if optimal_range == null:
		errors.append("optimal_range is required.")
		return errors
	for error: String in optimal_range.validate():
		errors.append("optimal_range: %s" % error)
	match factor:
		SimulationEnums.AbioticFactor.SOIL_PH:
			if optimal_range.min_value < 0.0 or optimal_range.max_value > 14.0:
				errors.append("optimal_range pH bounds must be in [0.0, 14.0].")
		SimulationEnums.AbioticFactor.LIGHT_INTENSITY, SimulationEnums.AbioticFactor.RELATIVE_HUMIDITY:
			if optimal_range.min_value < 0.0 or optimal_range.max_value > 1.0:
				errors.append("optimal_range normalized bounds must be in [0.0, 1.0].")
		SimulationEnums.AbioticFactor.ATMOSPHERIC_PRESSURE_KPA:
			if optimal_range.min_value <= 0.0 or optimal_range.max_value <= 0.0:
				errors.append("optimal_range pressure bounds must be greater than zero kPa.")
	return errors


func copy() -> AbioticRule:
	var result: AbioticRule = AbioticRule.new()
	result.factor = factor
	result.weight = weight
	if optimal_range != null:
		result.optimal_range = optimal_range.copy()
	return result
