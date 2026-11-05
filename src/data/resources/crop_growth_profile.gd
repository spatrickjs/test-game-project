class_name CropGrowthProfile
extends Resource
## Fictional gameplay tuning, not calibrated agronomic requirements.
## These values affect crop growth and harvest quality only.

@export_range(0.0, 1.0) var nitrogen_minimum: float = 0.4
@export_range(0.0, 1.0) var potassium_minimum: float = 0.4
@export_range(0.0, 14.0) var ph_minimum: float = 6.0
@export_range(0.0, 14.0) var ph_maximum: float = 8.0
@export var ph_falloff: float = 2.0
@export_range(0.0, 1.0) var moisture_minimum: float = 0.3
@export_range(0.0, 1.0) var moisture_maximum: float = 0.7
@export var moisture_falloff: float = 0.3
@export_range(0.0, 1.0) var vitality_loss_per_turn: float = 0.05
@export_range(0.0, 1.0) var quality_loss_per_turn: float = 0.025

func validate() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	for key: StringName in [&"nitrogen_minimum", &"potassium_minimum", &"moisture_minimum", &"moisture_maximum", &"vitality_loss_per_turn", &"quality_loss_per_turn"]:
		var value: float = get(key)
		if not is_finite(value) or value < 0.0 or value > 1.0:
			errors.append("%s must be finite and in [0, 1]." % key)
	for key: StringName in [&"ph_minimum", &"ph_maximum"]:
		var value: float = get(key)
		if not is_finite(value) or value < 0.0 or value > 14.0:
			errors.append("%s must be finite and in [0, 14]." % key)
	for key: StringName in [&"ph_falloff", &"moisture_falloff"]:
		var value: float = get(key)
		if not is_finite(value) or value <= 0.0:
			errors.append("%s must be finite and positive." % key)
	if ph_minimum > ph_maximum or moisture_minimum > moisture_maximum:
		errors.append("Optimal interval minimum must not exceed maximum.")
	return errors

func copy() -> CropGrowthProfile:
	var result: CropGrowthProfile = CropGrowthProfile.new()
	for key: StringName in [&"nitrogen_minimum", &"potassium_minimum", &"ph_minimum", &"ph_maximum", &"ph_falloff", &"moisture_minimum", &"moisture_maximum", &"moisture_falloff", &"vitality_loss_per_turn", &"quality_loss_per_turn"]:
		result.set(key, get(key))
	return result
