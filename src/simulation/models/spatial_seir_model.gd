class_name SpatialSEIRModel
extends RefCounted


func evaluate(cell: FieldCellState, disease: DiseaseData, hazard: float, dt: float, gamma_scale: float = 1.0) -> FieldCellState:
	return CompartmentMath.continuous(cell, disease, hazard, dt, true, gamma_scale)
