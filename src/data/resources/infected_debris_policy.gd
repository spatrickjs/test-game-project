class_name InfectedDebrisPolicy
extends Resource
## Fictional gameplay tuning, independent of disease simulation parameters.
@export var chance: float = 0.25
@export var random_seed: int = 2026


func validate() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if not is_finite(chance) or chance < 0.0 or chance > 1.0:
		errors.append("Infected debris chance must be finite and in [0, 1].")
	return errors
