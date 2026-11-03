class_name SpatialSIRModel
extends RefCounted


func evaluate(cell: FieldCellState, disease: DiseaseData, hazard: float, dt: float) -> FieldCellState:
	return CompartmentMath.continuous(cell, disease, hazard, dt, false)
