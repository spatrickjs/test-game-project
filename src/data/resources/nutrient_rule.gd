class_name NutrientRule
extends Resource
## Healthy/resistant nutrient interval. Values outside either bound increase
## crop stress or disease susceptibility. No penalty calculation lives here.

@export var nutrient: SimulationEnums.NutrientType = SimulationEnums.NutrientType.NITROGEN
@export var optimal_range: FloatRange = null
@export_range(0.0, 1.0, 0.01) var weight: float = 1.0


func validate() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if not SimulationEnums.NutrientType.values().has(nutrient):
		errors.append("nutrient has an invalid identifier.")
	if is_nan(weight) or is_inf(weight):
		errors.append("weight must be finite.")
	elif weight < 0.0 or weight > 1.0:
		errors.append("weight must be in [0.0, 1.0].")
	if optimal_range == null:
		errors.append("optimal_range is required.")
		return errors
	for error: String in optimal_range.validate():
		errors.append("optimal_range: %s" % error)
	if optimal_range.min_value < 0.0 or optimal_range.max_value > 1.0:
		errors.append("optimal_range bounds must be in [0.0, 1.0].")
	return errors


func copy() -> NutrientRule:
	var result: NutrientRule = NutrientRule.new()
	result.nutrient = nutrient
	result.weight = weight
	if optimal_range != null:
		result.optimal_range = optimal_range.copy()
	return result
