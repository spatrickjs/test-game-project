class_name TreatmentModifiers
extends RefCounted
## Per-cell modifiers resolved from active treatment effects.
## Feeds into TransmissionModifiers.evaluate and the recovery step.

## Transmission hazard multiplier (includes susceptibility and resilience effects).
var hazard_mult: float = 1.0
## Recovery rate scale (1 / recovery_period_mult).
var gamma_scale: float = 1.0
## Vitality loss multiplier.
var vitality_loss_mult: float = 1.0


static func default() -> TreatmentModifiers:
	return TreatmentModifiers.new()


func copy() -> TreatmentModifiers:
	var result: TreatmentModifiers = TreatmentModifiers.new()
	result.hazard_mult = hazard_mult
	result.gamma_scale = gamma_scale
	result.vitality_loss_mult = vitality_loss_mult
	return result
