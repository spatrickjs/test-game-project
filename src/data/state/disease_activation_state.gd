class_name DiseaseActivationState
extends RefCounted
## Detached session history; never stored in the shared policy resource.

var has_selected_disease: bool = false
var selected_disease_id: SimulationEnums.DiseaseId = SimulationEnums.DiseaseId.RICE_BLAST
var cooldown_remaining: int = 0
var introductions_committed: int = 0
var rng_state: int = 0

func validate() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if cooldown_remaining < 0 or introductions_committed < 0:
		errors.append("Activation counters must be nonnegative.")
	if has_selected_disease and not SimulationEnums.DiseaseId.values().has(selected_disease_id):
		errors.append("Selected disease ID is invalid.")
	return errors

func copy() -> DiseaseActivationState:
	var result: DiseaseActivationState = DiseaseActivationState.new()
	result.has_selected_disease = has_selected_disease
	result.selected_disease_id = selected_disease_id
	result.cooldown_remaining = cooldown_remaining
	result.introductions_committed = introductions_committed
	result.rng_state = rng_state
	return result
