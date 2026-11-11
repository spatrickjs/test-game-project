class_name DiseaseActivationState
extends RefCounted
## Detached session history; never stored in the shared policy resource.

var cooldown_remaining: int = 0
var introductions_committed: int = 0
var rng_state: int = 0

func validate() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if cooldown_remaining < 0 or introductions_committed < 0:
		errors.append("Activation counters must be nonnegative.")
	return errors

func copy() -> DiseaseActivationState:
	var result: DiseaseActivationState = DiseaseActivationState.new()
	result.cooldown_remaining = cooldown_remaining
	result.introductions_committed = introductions_committed
	result.rng_state = rng_state
	return result
