class_name TreatmentResolver
extends RefCounted
## Combines active treatment effects into per-cell TreatmentModifiers.
## Effects from the same treatment class are merged at commit time (no stacking);
## effects from different classes combine multiplicatively here.


## Resolves all active effects on a cell into modifiers.
static func resolve(cell: Vector2i, state: TreatmentState, config: TreatmentConfig) -> TreatmentModifiers:
	var mods: TreatmentModifiers = TreatmentModifiers.new()
	for effect: TreatmentEffect in state.effects_on(cell):
		var data: TreatmentData = config.get_data(effect.treatment_id)
		if data == null:
			continue
		var p: float = effect.potency
		# hazard_mult combines: transmission, susceptibility, and (1 - resilience)
		mods.hazard_mult *= lerpf(1.0, data.hazard_mult, p)
		mods.hazard_mult *= lerpf(1.0, data.susceptibility_mult, p)
		mods.hazard_mult *= 1.0 - data.resilience_bonus * p
		# gamma_scale = 1 / recovery_period_mult (lerped by potency)
		mods.gamma_scale *= lerpf(1.0, 1.0 / data.recovery_period_mult, p)
		mods.vitality_loss_mult *= lerpf(1.0, data.vitality_loss_mult, p)
	# Apply clamps
	mods.hazard_mult = maxf(mods.hazard_mult, config.min_hazard_mult)
	mods.gamma_scale = minf(mods.gamma_scale, config.max_gamma_scale)
	mods.vitality_loss_mult = maxf(mods.vitality_loss_mult, config.min_vitality_loss_mult)
	return mods


## Computes resistance potency for a group at a given turn.
static func resistance_potency(resistance_group: int, state: TreatmentState, config: TreatmentConfig, turn: int) -> float:
	if resistance_group == TreatmentData.ResistanceGroup.NONE:
		return 1.0
	var uses: int = state.usage_count(resistance_group, config.resistance_window_turns, turn)
	var over: int = maxi(0, uses - config.threshold)
	return maxf(config.potency_floor, 1.0 - config.penalty_per_extra_use * float(over))


## Computes enhancer potency with per-cell diminishing returns.
static func enhancer_potency(cell: Vector2i, state: TreatmentState, config: TreatmentConfig, turn: int) -> float:
	var n: int = state.enhancer_use_count(cell, config.resistance_window_turns, turn)
	return pow(config.enhancer_repeat_decay, float(n))
