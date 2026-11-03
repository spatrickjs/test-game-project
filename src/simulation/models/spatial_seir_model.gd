class_name SpatialSEIRModel
extends RefCounted


func evaluate(cell: FieldCellState, disease: DiseaseData, hazard: float, dt: float) -> FieldCellState:
	return CompartmentMath.continuous(cell, disease, hazard, dt, true)
