class_name SoilMoistureModel
extends RefCounted
## Normalized game hydration arithmetic, not a calibrated water-balance model.
static func next_moisture(current: float, rainfall: float, evaporation: float, rain_scale: float) -> float:
	if not is_finite(current) or current < 0.0 or current > 1.0:
		return NAN
	for value: float in [rainfall, evaporation, rain_scale]:
		if not is_finite(value) or value < 0.0:
			return NAN
	var delta: float = rainfall * rain_scale - evaporation
	if not is_finite(delta):
		return NAN
	return clampf(current + delta, 0.0, 1.0)
