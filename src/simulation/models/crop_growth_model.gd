class_name CropGrowthModel
extends RefCounted
## Pure crop-lifecycle evaluation; no disease-model inputs or outputs.

class Result:
	extends RefCounted
	var errors: PackedStringArray = PackedStringArray()
	var growth_elapsed_ticks: int = 0
	var growth_remainder: float = 0.0
	var vitality: float = 1.0
	var yield_quality_loss: float = 0.0
	var stress: float = 0.0
	var hydration: float = 1.0
	var growth_credit: float = 0.0

static func evaluate(cell: FieldCellState, crop: CropData) -> Result:
	var result: Result = Result.new()
	if cell == null or crop == null:
		result.errors.append("Cell and crop definition are required.")
		return result
	result.errors.append_array(cell.validate())
	result.errors.append_array(crop.validate())
	if not cell.has_crop or cell.crop_type != crop.crop_type or cell.soil == null:
		result.errors.append("An occupied compatible cell with soil is required.")
	if cell.growth_elapsed_ticks > crop.growth_ticks:
		result.errors.append("Growth exceeds crop maturity.")
	if not result.errors.is_empty():
		return result
	result.growth_elapsed_ticks = cell.growth_elapsed_ticks
	result.growth_remainder = cell.growth_remainder
	result.vitality = cell.vitality
	result.yield_quality_loss = cell.yield_quality_loss
	var profile: CropGrowthProfile = crop.growth_profile
	if profile != null:
		var n_stress: float = _deficiency(cell.soil.nitrogen, profile.nitrogen_minimum)
		var k_stress: float = _deficiency(cell.soil.potassium, profile.potassium_minimum)
		var ph_stress: float = _interval_stress(cell.soil.soil_ph, profile.ph_minimum, profile.ph_maximum, profile.ph_falloff)
		var water_stress: float = _interval_stress(cell.soil.moisture, profile.moisture_minimum, profile.moisture_maximum, profile.moisture_falloff)
		result.hydration = 1.0 - water_stress
		result.stress = maxf(maxf(n_stress, k_stress), maxf(ph_stress, water_stress))
		result.vitality = maxf(0.0, cell.vitality - result.stress * profile.vitality_loss_per_turn)
		result.yield_quality_loss = minf(1.0, cell.yield_quality_loss + result.stress * profile.quality_loss_per_turn)
	# Use pre-turn vitality. Mature crops still accumulate neglect penalties.
	if cell.growth_elapsed_ticks < crop.growth_ticks:
		result.growth_credit = (1.0 - result.stress) * cell.vitality
		var credit: float = cell.growth_remainder + result.growth_credit
		var whole_ticks: int = floori(credit)
		result.growth_elapsed_ticks = mini(crop.growth_ticks, cell.growth_elapsed_ticks + whole_ticks)
		result.growth_remainder = credit - float(whole_ticks)
	if result.growth_elapsed_ticks == crop.growth_ticks:
		result.growth_remainder = 0.0
	return result

static func _deficiency(value: float, minimum: float) -> float:
	return clampf((minimum - value) / minimum, 0.0, 1.0) if minimum > 0.0 else 0.0

static func _interval_stress(value: float, minimum: float, maximum: float, falloff: float) -> float:
	return clampf(maxf(maxf(minimum - value, value - maximum), 0.0) / falloff, 0.0, 1.0)
