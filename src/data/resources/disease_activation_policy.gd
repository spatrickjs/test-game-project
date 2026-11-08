class_name DiseaseActivationPolicy
extends Resource
## Authored game scheduling, not calibrated outbreak probabilities.

@export var enabled: bool = true
@export var allowed_disease_ids: Array[SimulationEnums.DiseaseId] = [SimulationEnums.DiseaseId.RICE_BLAST]
@export_range(1, 1000, 1, "or_greater") var first_eligible_turn: int = 3
@export_range(0.0, 1.0) var chance_per_eligible_turn: float = 0.50
@export_range(0, 1000, 1, "or_greater") var cooldown_turns: int = 2
@export_range(0, 1000, 1, "or_greater") var max_introductions_per_session: int = 5
@export var random_seed: int = 2026
@export_multiline var design_note: String = "Illustrative game encounters; frequency and timing are designer choices, not measured outbreak probabilities."

func validate() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if first_eligible_turn < 1 or cooldown_turns < 0 or max_introductions_per_session < 0:
		errors.append("Activation turn must be positive; cooldown and limit must be nonnegative.")
	if not is_finite(chance_per_eligible_turn) or chance_per_eligible_turn < 0.0 or chance_per_eligible_turn > 1.0:
		errors.append("Activation chance must be finite and in [0, 1].")
	var seen: Array[SimulationEnums.DiseaseId] = []
	for disease_id: SimulationEnums.DiseaseId in allowed_disease_ids:
		if not SimulationEnums.DiseaseId.values().has(disease_id) or seen.has(disease_id):
			errors.append("Allowed diseases must have valid, unique IDs.")
		seen.append(disease_id)
	return errors
