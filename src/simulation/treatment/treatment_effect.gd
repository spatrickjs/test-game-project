class_name TreatmentEffect
extends RefCounted
## A single active treatment effect on one cell.
## Potency is fixed at apply time (resistance effectiveness or enhancer decay).

var treatment_id: StringName = &""
var cell: Vector2i = Vector2i.ZERO
var remaining_turns: int = 0
## Fixed at application: 1.0 = full strength, 0.4 = floor, etc.
var potency: float = 1.0
var applied_turn: int = 0


func to_dict() -> Dictionary:
	return {
		"treatment_id": String(treatment_id),
		"cell_x": cell.x,
		"cell_y": cell.y,
		"remaining_turns": remaining_turns,
		"potency": potency,
		"applied_turn": applied_turn,
	}


static func from_dict(data: Dictionary) -> TreatmentEffect:
	var effect: TreatmentEffect = TreatmentEffect.new()
	effect.treatment_id = StringName(data.get("treatment_id", ""))
	effect.cell = Vector2i(data.get("cell_x", 0), data.get("cell_y", 0))
	effect.remaining_turns = int(data.get("remaining_turns", 0))
	effect.potency = float(data.get("potency", 1.0))
	effect.applied_turn = int(data.get("applied_turn", 0))
	return effect


func copy() -> TreatmentEffect:
	var result: TreatmentEffect = TreatmentEffect.new()
	result.treatment_id = treatment_id
	result.cell = cell
	result.remaining_turns = remaining_turns
	result.potency = potency
	result.applied_turn = applied_turn
	return result
