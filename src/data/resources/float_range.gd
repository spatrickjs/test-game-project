class_name FloatRange
extends Resource
## Inclusive interval. Units and domain restrictions belong to the owning rule.

@export var min_value: float = 0.0
@export var max_value: float = 1.0


func validate() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if is_nan(min_value) or is_inf(min_value):
		errors.append("min_value must be finite.")
	if is_nan(max_value) or is_inf(max_value):
		errors.append("max_value must be finite.")
	if min_value > max_value:
		errors.append("min_value must be less than or equal to max_value.")
	return errors


func copy() -> FloatRange:
	var result: FloatRange = FloatRange.new()
	result.min_value = min_value
	result.max_value = max_value
	return result
