class_name TreatmentConfig
extends Resource
## Global tunables shared by all treatments. Single resource instance.

@export_group("Queue")
@export var max_queued_per_turn: int = 2

@export_group("Resistance")
@export var resistance_window_turns: int = 10
@export var threshold: int = 2
@export var penalty_per_extra_use: float = 0.15
@export var potency_floor: float = 0.4

@export_group("Enhancer")
@export var enhancer_repeat_decay: float = 0.7

@export_group("Clamps")
@export var min_hazard_mult: float = 0.2
@export var max_gamma_scale: float = 10.0
@export var min_vitality_loss_mult: float = 0.0

@export_group("Phase 2 - Vector")
@export var vector_growth_rate: float = 0.1
@export var rebound_factor: float = 0.8
@export var beneficial_index_recovery_step: float = 0.05

@export_group("Registry")
## All treatment definitions, keyed by treatment_id for lookup.
@export var treatments: Array[TreatmentData] = []


func get_data(treatment_id: StringName) -> TreatmentData:
	for t: TreatmentData in treatments:
		if t != null and t.treatment_id == treatment_id:
			return t
	return null


func validate() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if max_queued_per_turn < 1:
		errors.append("max_queued_per_turn must be at least 1.")
	if resistance_window_turns < 1:
		errors.append("resistance_window_turns must be at least 1.")
	if threshold < 0:
		errors.append("threshold must be nonnegative.")
	if is_nan(penalty_per_extra_use) or penalty_per_extra_use < 0.0:
		errors.append("penalty_per_extra_use must be nonnegative.")
	if is_nan(potency_floor) or potency_floor < 0.0 or potency_floor > 1.0:
		errors.append("potency_floor must be in [0.0, 1.0].")
	if is_nan(enhancer_repeat_decay) or enhancer_repeat_decay <= 0.0 or enhancer_repeat_decay > 1.0:
		errors.append("enhancer_repeat_decay must be in (0.0, 1.0].")
	if is_nan(min_hazard_mult) or min_hazard_mult < 0.0:
		errors.append("min_hazard_mult must be nonnegative.")
	if is_nan(max_gamma_scale) or max_gamma_scale < 1.0:
		errors.append("max_gamma_scale must be at least 1.0.")
	if is_nan(vector_growth_rate) or vector_growth_rate < 0.0:
		errors.append("vector_growth_rate must be nonnegative.")
	if is_nan(rebound_factor) or rebound_factor < 0.0:
		errors.append("rebound_factor must be nonnegative.")
	if is_nan(beneficial_index_recovery_step) or beneficial_index_recovery_step < 0.0 or beneficial_index_recovery_step > 1.0:
		errors.append("beneficial_index_recovery_step must be in [0.0, 1.0].")
	var seen_ids: Array[StringName] = []
	for index: int in range(treatments.size()):
		var t: TreatmentData = treatments[index]
		if t == null:
			errors.append("treatments[%d]: entry must not be null." % index)
			continue
		if seen_ids.has(t.treatment_id):
			errors.append("treatments[%d]: duplicate treatment_id." % index)
		else:
			seen_ids.append(t.treatment_id)
		for error: String in t.validate():
			errors.append("treatments[%d]: %s" % [index, error])
	return errors


func copy() -> TreatmentConfig:
	var result: TreatmentConfig = TreatmentConfig.new()
	result.max_queued_per_turn = max_queued_per_turn
	result.resistance_window_turns = resistance_window_turns
	result.threshold = threshold
	result.penalty_per_extra_use = penalty_per_extra_use
	result.potency_floor = potency_floor
	result.enhancer_repeat_decay = enhancer_repeat_decay
	result.min_hazard_mult = min_hazard_mult
	result.max_gamma_scale = max_gamma_scale
	result.min_vitality_loss_mult = min_vitality_loss_mult
	result.vector_growth_rate = vector_growth_rate
	result.rebound_factor = rebound_factor
	result.beneficial_index_recovery_step = beneficial_index_recovery_step
	for t: TreatmentData in treatments:
		if t == null:
			result.treatments.append(null)
		else:
			result.treatments.append(t.copy())
	return result
