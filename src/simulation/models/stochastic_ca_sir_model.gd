class_name StochasticCASIRModel
extends RefCounted


func evaluate(cell: FieldCellState, disease: DiseaseData, hazard: float, dt: float, rng: RandomNumberGenerator) -> FieldCellState:
	var next: FieldCellState = cell.copy()
	var state: int = CompartmentMath.one_hot_index(cell)
	# Exactly one transition per tick; CA entry has already been validated.
	match state:
		0:
			if hazard > 0.0 and _draw(CompartmentMath.probability(hazard, dt), rng):
				state = 2
		2:
			if _draw(CompartmentMath.probability(disease.gamma, dt), rng):
				state = 4 if _draw(disease.mortality_probability, rng) else 3
		3:
			if _draw(CompartmentMath.probability(disease.xi, dt), rng):
				state = 0
	CompartmentMath.set_one_hot(next, state)
	return next


func _draw(probability: float, rng: RandomNumberGenerator) -> bool:
	# randf may include 1.0; endpoints must remain exact.
	if probability <= 0.0:
		return false
	if probability >= 1.0:
		return true
	return rng.randf() < probability
