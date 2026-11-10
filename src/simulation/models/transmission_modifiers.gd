class_name TransmissionModifiers
extends RefCounted
## Validated recipient-side responses, shared by all models.
## Generic abiotic/susceptibility arrays and base_immunity are not also applied.

class Result:
	extends RefCounted
	var protection: float = 1.0
	var weather: float = 1.0
	var nutrient: float = 1.0
	var effective_beta: float = 0.0
	var hazard: float = 0.0
	var weather_capped: bool = false
	var beta_capped: bool = false
	var hazard_capped: bool = false


static func needs_crop(profile: TransmissionModifierProfile) -> bool:
	return profile != null and (profile.nitrogen_excess_strength > 0.0 or profile.potassium_protection_strength > 0.0)


static func evaluate(disease: DiseaseData, environment: AbioticState, soil: SoilState, crop: CropData, pressure: float, protection_bonus: float = 0.0) -> Result:
	var result: Result = Result.new()
	var profile: TransmissionModifierProfile = disease.transmission_modifier_profile
	var beta_cap: float = 1.7976931348623157e308
	var hazard_cap: float = beta_cap
	if profile != null:
		beta_cap = profile.maximum_effective_beta
		hazard_cap = profile.maximum_hazard
		var temperature: float = 1.0
		if profile.temperature_enabled:
			var distance: float = maxf(0.0, maxf(profile.optimal_temperature_min - environment.temperature_celsius, environment.temperature_celsius - profile.optimal_temperature_max))
			temperature = 1.0 - (1.0 - profile.minimum_weather_multiplier) * clampf(distance / profile.temperature_falloff_celsius, 0.0, 1.0)
		var humidity: float = 1.0 + profile.humidity_sensitivity * clampf((environment.relative_humidity - profile.humidity_reference) / (1.0 - profile.humidity_reference), 0.0, 1.0)
		var weather: float = temperature * humidity
		result.weather = clampf(weather, profile.minimum_weather_multiplier, profile.maximum_weather_multiplier)
		result.weather_capped = result.weather != weather
		if crop != null:
			for rule: NutrientRule in crop.nutrient_requirement_rules:
				if rule.nutrient == SimulationEnums.NutrientType.NITROGEN and profile.nitrogen_excess_strength > 0.0:
					var upper: float = rule.optimal_range.max_value
					var excess: float = clampf((soil.nitrogen - upper) / (1.0 - upper), 0.0, 1.0) if upper < 1.0 else 0.0
					result.nutrient *= 1.0 + profile.nitrogen_excess_strength * excess
				elif rule.nutrient == SimulationEnums.NutrientType.POTASSIUM and profile.potassium_protection_strength > 0.0:
					var distance: float = maxf(0.0, maxf(rule.optimal_range.min_value - soil.potassium, soil.potassium - rule.optimal_range.max_value))
					var benefit: float = 1.0 - clampf(distance / profile.potassium_falloff, 0.0, 1.0)
					result.nutrient *= 1.0 - profile.potassium_protection_strength * benefit
	result.protection = 1.0 - protection_bonus
	var beta_factors: Array[float] = [disease.beta, result.weather, result.nutrient, result.protection]
	result.beta_capped = _exceeds(beta_factors, beta_cap)
	result.effective_beta = _product(beta_factors, beta_cap)
	var hazard_factors: Array[float] = [result.effective_beta, pressure]
	result.hazard_capped = _exceeds(hazard_factors, hazard_cap)
	result.hazard = _product(hazard_factors, hazard_cap)
	return result


static func _exceeds(factors: Array[float], cap: float) -> bool:
	var logarithm: float = 0.0
	for factor: float in factors:
		if factor == 0.0:
			return false
		logarithm += log(factor)
	return logarithm > log(cap)


static func _product(factors: Array[float], cap: float) -> float:
	# Log comparison prevents overflow without prematurely capping a product
	# before protective factors have been included.
	if _exceeds(factors, cap):
		return cap
	var logarithm: float = 0.0
	var product: float = 1.0
	for factor: float in factors:
		if factor == 0.0:
			return 0.0
		logarithm += log(factor)
		product *= factor
	if is_finite(product) and product > 0.0:
		return minf(product, cap)
	return minf(exp(logarithm), cap)
