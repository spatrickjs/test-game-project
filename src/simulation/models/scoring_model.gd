class_name ScoringModel
extends RefCounted
## Pure harvest-scoring calculation; no UI or authoritative state dependencies.
## Mirrors the CropGrowthModel pattern: a static, side-effect-free evaluator.

class Result:
	extends RefCounted
	var errors: PackedStringArray = PackedStringArray()
	var base_score: int = 0
	var score: float = 0.0


## Returns the points a harvest is worth, given the crop's authored base score
## and the harvest's quality multiplier (0.0–1.0). The caller gates on success;
## this model only computes the value so the receipt is self-contained before
## any observer receives the queued_harvest_completed signal.
static func evaluate(harvest: HarvestResult, crop: CropData) -> Result:
	var result: Result = Result.new()
	if harvest == null or crop == null:
		result.errors.append("Harvest result and crop definition are required.")
		return result
	if crop.base_score < 0:
		result.errors.append("base_score must not be negative.")
		return result
	result.base_score = crop.base_score
	var quality: float = clampf(harvest.quality_multiplier, 0.0, 1.0)
	result.score = float(crop.base_score) * quality
	return result
