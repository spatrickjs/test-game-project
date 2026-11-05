class_name SoilToolController
extends Node
## Inspector-tuned additions in normalized units; actions never advance time.
@export var farming_controller: FarmingController
@export_range(0.0, 1.0, 0.01) var water_infusion_amount: float = 0.1
@export_range(0.0, 1.0, 0.01) var nitrogen_boost_amount: float = 0.1
@export_range(0.0, 1.0, 0.01) var potassium_boost_amount: float = 0.1
var last_error: String = ""

func validate_configuration() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if farming_controller == null:
		errors.append("Assign FarmingController.")
	for key: StringName in [&"water_infusion_amount", &"nitrogen_boost_amount", &"potassium_boost_amount"]:
		var value: float = get(key)
		if not is_finite(value) or value < 0.0 or value > 1.0:
			errors.append("%s must be finite and in [0, 1]." % key)
	return errors

func water(coordinates: Vector2i) -> bool:
	return _apply(coordinates, Vector3(water_infusion_amount, 0.0, 0.0))

func fertilize(coordinates: Vector2i) -> bool:
	return _apply(coordinates, Vector3(0.0, nitrogen_boost_amount, potassium_boost_amount))

func _apply(coordinates: Vector2i, additions: Vector3) -> bool:
	var errors: PackedStringArray = validate_configuration()
	if not errors.is_empty():
		last_error = "\n".join(errors)
		return false
	var success: bool = farming_controller.apply_soil_additions(coordinates, additions)
	last_error = farming_controller.last_error
	return success
