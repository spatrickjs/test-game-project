class_name FieldCellState
extends RefCounted
## Passive runtime state; only Logic or Simulation should mutate this object.
## Continuous models own fractions; CA owns categorical state and uses one-hot
## fractions. Algorithm-specific consistency is checked by the future runner,
## not inferred here from a disease's default_algorithm.

const FRACTION_SUM_TOLERANCE: float = 0.00001

var coordinates: Vector2i = Vector2i.ZERO
var terrain_type: SimulationEnums.TerrainType = SimulationEnums.TerrainType.GRASS
var soil: SoilState = null

var inoculation_turns_remaining: int = 0
var inoculation_bonus: float = 0.0

func is_inoculated() -> bool:
	return has_crop and dead_fraction < 1.0 and removed_outcome != SimulationEnums.RemovedOutcome.DEAD and inoculation_turns_remaining > 0 and inoculation_bonus > 0.0


var has_crop: bool = false
## Ignored when has_crop is false.
var crop_type: SimulationEnums.CropType = SimulationEnums.CropType.SUGARCANE
var growth_elapsed_ticks: int = 0
var growth_remainder: float = 0.0
## Neutral defaults also apply to empty cells; meaningful only when occupied.
var vitality: float = 1.0
var yield_quality_loss: float = 0.0

## Categorical fields are not a thresholded representation of continuous values.
var sir_state: SimulationEnums.SIRState = SimulationEnums.SIRState.S
var removed_outcome: SimulationEnums.RemovedOutcome = SimulationEnums.RemovedOutcome.NONE
var has_active_disease: bool = false
## Ignored when has_active_disease is false.
var active_disease_id: SimulationEnums.DiseaseId = SimulationEnums.DiseaseId.RSSI

var susceptible_fraction: float = 0.0
var exposed_fraction: float = 0.0
var infected_fraction: float = 0.0
var recovered_immune_fraction: float = 0.0
var dead_fraction: float = 0.0


## Reset crop state after setting has_crop/crop_type. Preserve soil and terrain.
func reset_crop_state() -> void:
	inoculation_turns_remaining = 0
	inoculation_bonus = 0.0
	growth_elapsed_ticks = 0
	growth_remainder = 0.0
	vitality = 1.0
	yield_quality_loss = 0.0
	sir_state = SimulationEnums.SIRState.S
	removed_outcome = SimulationEnums.RemovedOutcome.NONE
	has_active_disease = false
	active_disease_id = SimulationEnums.DiseaseId.RSSI
	susceptible_fraction = 1.0 if has_crop else 0.0
	exposed_fraction = 0.0
	infected_fraction = 0.0
	recovered_immune_fraction = 0.0
	dead_fraction = 0.0
	if not has_crop:
		crop_type = SimulationEnums.CropType.SUGARCANE


func is_mature(crop_data: CropData) -> bool:
	if not has_crop or crop_data == null:
		return false
	if crop_data.crop_type != crop_type or crop_data.growth_ticks < 1:
		return false
	return growth_elapsed_ticks >= crop_data.growth_ticks


## Structural validation only; terrain permissions need the terrain catalog.
func validate() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	_validate_fraction("inoculation_bonus", inoculation_bonus, errors)
	if inoculation_turns_remaining < 0 or ((inoculation_turns_remaining == 0) != (inoculation_bonus == 0.0)):
		errors.append("Inoculation duration and bonus must both be active or both zero.")
	if not has_crop and (inoculation_turns_remaining != 0 or inoculation_bonus != 0.0):
		errors.append("Empty cells must clear inoculation.")
	_validate_fraction("vitality", vitality, errors)
	_validate_fraction("yield_quality_loss", yield_quality_loss, errors)
	if not is_finite(growth_remainder) or growth_remainder < 0.0 or growth_remainder >= 1.0:
		errors.append("growth_remainder must be finite and in [0, 1).")
	if coordinates.x < 0 or coordinates.y < 0:
		errors.append("coordinates must be nonnegative.")
	if not SimulationEnums.TerrainType.values().has(terrain_type):
		errors.append("terrain_type has an invalid identifier.")
	if growth_elapsed_ticks < 0:
		errors.append("growth_elapsed_ticks must be nonnegative.")
	if has_crop and not SimulationEnums.CropType.values().has(crop_type):
		errors.append("crop_type has an invalid identifier.")
	if has_active_disease and not SimulationEnums.DiseaseId.values().has(active_disease_id):
		errors.append("active_disease_id has an invalid identifier.")
	if not SimulationEnums.SIRState.values().has(sir_state):
		errors.append("sir_state has an invalid identifier.")
	if not SimulationEnums.RemovedOutcome.values().has(removed_outcome):
		errors.append("removed_outcome has an invalid identifier.")
	if sir_state == SimulationEnums.SIRState.R:
		if removed_outcome == SimulationEnums.RemovedOutcome.NONE:
			errors.append("categorical R requires a removed_outcome.")
	elif removed_outcome != SimulationEnums.RemovedOutcome.NONE:
		errors.append("removed_outcome must be NONE outside categorical R.")
	if soil != null:
		for error: String in soil.validate():
			errors.append("soil: %s" % error)
	_validate_fraction("susceptible_fraction", susceptible_fraction, errors)
	_validate_fraction("exposed_fraction", exposed_fraction, errors)
	_validate_fraction("infected_fraction", infected_fraction, errors)
	_validate_fraction("recovered_immune_fraction", recovered_immune_fraction, errors)
	_validate_fraction("dead_fraction", dead_fraction, errors)
	var total: float = (
		susceptible_fraction + exposed_fraction + infected_fraction
		+ recovered_immune_fraction + dead_fraction
	)
	if has_crop:
		if not is_nan(total) and not is_inf(total):
			if absf(total - 1.0) > FRACTION_SUM_TOLERANCE:
				errors.append("occupied cell compartment fractions must sum to 1.0.")
	else:
		if growth_remainder != 0.0 or vitality != 1.0 or yield_quality_loss != 0.0:
			errors.append("empty cells must reset lifecycle state.")
		if growth_elapsed_ticks != 0:
			errors.append("empty cells must have zero growth_elapsed_ticks.")
		if has_active_disease:
			errors.append("empty cells must not have an active disease.")
		if sir_state != SimulationEnums.SIRState.S or removed_outcome != SimulationEnums.RemovedOutcome.NONE:
			errors.append("empty cells must reset categorical state to S/NONE.")
		if susceptible_fraction != 0.0 or exposed_fraction != 0.0 or infected_fraction != 0.0 or recovered_immune_fraction != 0.0 or dead_fraction != 0.0:
			errors.append("empty cells must have zero compartment fractions.")
	return errors


## Copies values without repairing invalid state or retaining shared soil.
func copy() -> FieldCellState:
	var result: FieldCellState = FieldCellState.new()
	result.inoculation_turns_remaining = inoculation_turns_remaining
	result.inoculation_bonus = inoculation_bonus
	result.coordinates = coordinates
	result.terrain_type = terrain_type
	result.has_crop = has_crop
	result.crop_type = crop_type
	result.growth_elapsed_ticks = growth_elapsed_ticks
	result.growth_remainder = growth_remainder
	result.vitality = vitality
	result.yield_quality_loss = yield_quality_loss
	result.sir_state = sir_state
	result.removed_outcome = removed_outcome
	result.has_active_disease = has_active_disease
	result.active_disease_id = active_disease_id
	result.susceptible_fraction = susceptible_fraction
	result.exposed_fraction = exposed_fraction
	result.infected_fraction = infected_fraction
	result.recovered_immune_fraction = recovered_immune_fraction
	result.dead_fraction = dead_fraction
	if soil != null:
		result.soil = soil.copy()
	return result


func _validate_fraction(
	property_name: String,
	value: float,
	errors: PackedStringArray
) -> void:
	if is_nan(value) or is_inf(value):
		errors.append("%s must be finite." % property_name)
	elif value < 0.0 or value > 1.0:
		errors.append("%s must be in [0.0, 1.0]." % property_name)
