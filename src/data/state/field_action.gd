class_name FieldAction
extends RefCounted
## Detached task description. No rendering coordinates or asset references.

var id: int = 0
var kind: SimulationEnums.FieldActionKind = SimulationEnums.FieldActionKind.PLANT
var target: Vector2i = Vector2i.ZERO
var source: Vector2i = Vector2i(-1, -1)
var crop_type: SimulationEnums.CropType = SimulationEnums.CropType.SUGARCANE
var additions: Vector3 = Vector3.ZERO
var source_visited: bool = false
var target_revision: int = 0
var source_revision: int = 0

func stop_coordinates() -> Vector2i:
	return source if kind == SimulationEnums.FieldActionKind.MOVE_CROP and not source_visited else target

func copy() -> FieldAction:
	var result: FieldAction = FieldAction.new()
	result.id = id
	result.kind = kind
	result.target = target
	result.source = source
	result.crop_type = crop_type
	result.additions = additions
	result.source_visited = source_visited
	result.target_revision = target_revision
	result.source_revision = source_revision
	return result
