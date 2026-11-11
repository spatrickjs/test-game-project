class_name TreatmentData
extends Resource
## Data-driven treatment definition. One resource per treatment product.
## Effects are multipliers; 1.0 / 0.0 = no effect. Potency is resolved at apply time.

enum TargetMode { AREA, CELL_OR_AREA }
enum AppliesTo { INFECTED, HEALTHY_OR_PRE_INFECTION, ANY }
enum ResistanceGroup { NONE, FUNGICIDE, BACTERICIDE }

@export_group("Identity")
@export var treatment_id: StringName = &""
@export var display_name: String = ""
@export var cost: int = 0
@export var cooldown_turns: int = 0
@export var duration_turns: int = 1

@export_group("Targeting")
@export var target_mode: TargetMode = TargetMode.AREA
## 1 = 3x3 area. Used when target_mode is AREA.
@export var area_radius: int = 1
@export var applies_to: AppliesTo = AppliesTo.ANY
## DiseaseCategory values; empty = any category allowed.
@export var allowed_categories: Array[int] = []
@export var requires_vector_borne: bool = false
@export var resistance_group: ResistanceGroup = ResistanceGroup.NONE

@export_group("Effects")
## Transmission hazard multiplier.
@export var hazard_mult: float = 1.0
## Susceptibility multiplier (applied to hazard, not to compartment fractions).
@export var susceptibility_mult: float = 1.0
## Recovery period multiplier; gamma_scale = 1.0 / recovery_period_mult.
@export var recovery_period_mult: float = 1.0
## Resilience bonus (reduces hazard by this fraction of potency).
@export var resilience_bonus: float = 0.0
## Vitality loss multiplier.
@export var vitality_loss_mult: float = 1.0
## >= 0 sets vector pressure (Insecticide = 0). -1.0 = no effect.
@export var vector_pressure_override: float = -1.0
@export var beneficial_index_delta: float = 0.0


## Reports invalid configuration without mutation.
func validate() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if treatment_id == &"":
		errors.append("treatment_id must not be empty.")
	if display_name.strip_edges().is_empty():
		errors.append("display_name must not be blank.")
	if cost < 0:
		errors.append("cost must be nonnegative.")
	if cooldown_turns < 0:
		errors.append("cooldown_turns must be nonnegative.")
	if duration_turns < 1:
		errors.append("duration_turns must be at least 1.")
	if area_radius < 1:
		errors.append("area_radius must be at least 1.")
	if not TargetMode.values().has(target_mode):
		errors.append("target_mode has an invalid identifier.")
	if not AppliesTo.values().has(applies_to):
		errors.append("applies_to has an invalid identifier.")
	if not ResistanceGroup.values().has(resistance_group):
		errors.append("resistance_group has an invalid identifier.")
	_validate_mult("hazard_mult", hazard_mult, errors)
	_validate_mult("susceptibility_mult", susceptibility_mult, errors)
	_validate_mult("recovery_period_mult", recovery_period_mult, errors)
	_validate_mult("vitality_loss_mult", vitality_loss_mult, errors)
	if is_nan(resilience_bonus) or is_inf(resilience_bonus) or resilience_bonus < 0.0 or resilience_bonus > 1.0:
		errors.append("resilience_bonus must be finite and in [0.0, 1.0].")
	if is_nan(vector_pressure_override) or is_inf(vector_pressure_override) or vector_pressure_override < -1.0:
		errors.append("vector_pressure_override must be >= -1.0.")
	if is_nan(beneficial_index_delta) or is_inf(beneficial_index_delta):
		errors.append("beneficial_index_delta must be finite.")
	for cat: int in allowed_categories:
		if cat < 0 or cat > 2:
			errors.append("allowed_categories contains an invalid category value: %d" % cat)
	return errors


func copy() -> TreatmentData:
	var result: TreatmentData = TreatmentData.new()
	result.treatment_id = treatment_id
	result.display_name = display_name
	result.cost = cost
	result.cooldown_turns = cooldown_turns
	result.duration_turns = duration_turns
	result.target_mode = target_mode
	result.area_radius = area_radius
	result.applies_to = applies_to
	result.allowed_categories = allowed_categories.duplicate()
	result.requires_vector_borne = requires_vector_borne
	result.resistance_group = resistance_group
	result.hazard_mult = hazard_mult
	result.susceptibility_mult = susceptibility_mult
	result.recovery_period_mult = recovery_period_mult
	result.resilience_bonus = resilience_bonus
	result.vitality_loss_mult = vitality_loss_mult
	result.vector_pressure_override = vector_pressure_override
	result.beneficial_index_delta = beneficial_index_delta
	return result


func _validate_mult(property_name: String, value: float, errors: PackedStringArray) -> void:
	if is_nan(value) or is_inf(value):
		errors.append("%s must be finite." % property_name)
	elif value < 0.0:
		errors.append("%s must be nonnegative." % property_name)
