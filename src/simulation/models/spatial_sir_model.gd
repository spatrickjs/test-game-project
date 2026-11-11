class_name SpatialSIRModel
extends RefCounted


func evaluate(cell: FieldCellState, disease: DiseaseData, hazard: float, dt: float, gamma_scale: float = 1.0) -> FieldCellState:
	return CompartmentMath.continuous(cell, disease, hazard, dt, false, gamma_scale)
