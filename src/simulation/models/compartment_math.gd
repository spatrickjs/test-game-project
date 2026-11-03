class_name CompartmentMath
extends RefCounted


static func probability(rate: float, dt: float) -> float:
	# Zero first avoids 0 * INF when a product of finite inputs overflows.
	if rate <= 0.0:
		return 0.0
	return clampf(1.0 - exp(-rate * dt), 0.0, 1.0)


static func fractions(cell: FieldCellState) -> Array[float]:
	return [cell.susceptible_fraction, cell.exposed_fraction, cell.infected_fraction,
		cell.recovered_immune_fraction, cell.dead_fraction]


static func one_hot_index(cell: FieldCellState) -> int:
	var values: Array[float] = fractions(cell)
	var selected: int = -1
	for index: int in range(values.size()):
		if values[index] == 1.0 and selected == -1:
			selected = index
		elif values[index] != 0.0:
			return -1
	return selected


static func set_one_hot(cell: FieldCellState, index: int) -> void:
	cell.susceptible_fraction = 1.0 if index == 0 else 0.0
	cell.exposed_fraction = 1.0 if index == 1 else 0.0
	cell.infected_fraction = 1.0 if index == 2 else 0.0
	cell.recovered_immune_fraction = 1.0 if index == 3 else 0.0
	cell.dead_fraction = 1.0 if index == 4 else 0.0
	cell.sir_state = SimulationEnums.SIRState.S
	cell.removed_outcome = SimulationEnums.RemovedOutcome.NONE
	if index == 2:
		cell.sir_state = SimulationEnums.SIRState.I
	elif index >= 3:
		cell.sir_state = SimulationEnums.SIRState.R
		cell.removed_outcome = SimulationEnums.RemovedOutcome.RECOVERED_IMMUNE if index == 3 else SimulationEnums.RemovedOutcome.DEAD


static func continuous(cell: FieldCellState, disease: DiseaseData, hazard: float, dt: float, seir: bool) -> FieldCellState:
	var next: FieldCellState = cell.copy()
	var infection: float = cell.susceptible_fraction * probability(hazard, dt) if hazard > 0.0 else 0.0
	var incubation: float = cell.exposed_fraction * probability(disease.sigma, dt) if seir else 0.0
	var removal: float = cell.infected_fraction * probability(disease.gamma, dt)
	var waning: float = cell.recovered_immune_fraction * probability(disease.xi, dt)
	var deaths: float = removal * disease.mortality_probability
	next.susceptible_fraction = clampf(cell.susceptible_fraction - infection + waning, 0.0, 1.0)
	next.exposed_fraction = clampf(cell.exposed_fraction + infection - incubation, 0.0, 1.0) if seir else 0.0
	next.infected_fraction = clampf(cell.infected_fraction + (incubation if seir else infection) - removal, 0.0, 1.0)
	next.recovered_immune_fraction = clampf(cell.recovered_immune_fraction + removal - deaths - waning, 0.0, 1.0)
	next.dead_fraction = clampf(cell.dead_fraction + deaths, 0.0, 1.0)
	# Continuous fractions are authoritative; do not invent a thresholded category.
	return next
