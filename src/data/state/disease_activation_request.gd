class_name DiseaseActivationRequest
extends RefCounted
## Proposed game-state change; only FarmingController may apply it.

var disease_id: SimulationEnums.DiseaseId = SimulationEnums.DiseaseId.RICE_BLAST
var coordinates: Vector2i = Vector2i.ZERO
