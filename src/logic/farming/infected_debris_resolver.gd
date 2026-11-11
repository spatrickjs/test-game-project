class_name InfectedDebrisResolver
extends RefCounted


static func is_eligible(cell: FieldCellState) -> bool:
	return cell.has_crop and cell.has_active_disease and (
		cell.sir_state == SimulationEnums.SIRState.I or cell.infected_fraction > 0.0
	)


static func resolve(chance: float, draw: float) -> bool:
	return is_finite(chance) and chance >= 0.0 and chance <= 1.0 and is_finite(draw) and draw >= 0.0 and draw < 1.0 and draw < chance
