extends SceneTree
## Property-style unit tests for the pure ScoringModel evaluator.

var _failures: PackedStringArray = PackedStringArray()

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var crop := CropData.new()
	crop.display_name = "Test crop"
	crop.base_score = 150
	var harvest := HarvestResult.new()
	harvest.success = true
	harvest.quality_multiplier = 1.0

	var r := ScoringModel.evaluate(harvest, crop)
	_check(r.errors.is_empty() and r.base_score == 150 and is_equal_approx(r.score, 150.0), "Perfect harvest awards full base score")

	harvest.quality_multiplier = 0.5
	r = ScoringModel.evaluate(harvest, crop)
	_check(r.errors.is_empty() and is_equal_approx(r.score, 75.0), "50% quality halves the score")

	harvest.quality_multiplier = -0.5
	r = ScoringModel.evaluate(harvest, crop)
	_check(r.errors.is_empty() and r.score == 0.0, "Negative quality clamps to zero")

	harvest.quality_multiplier = 2.0
	r = ScoringModel.evaluate(harvest, crop)
	_check(r.errors.is_empty() and r.score == 150.0, "Over-unity quality clamps to base score")

	crop.base_score = 0
	harvest.quality_multiplier = 1.0
	r = ScoringModel.evaluate(harvest, crop)
	_check(r.errors.is_empty() and r.score == 0.0, "Zero base score yields zero points")

	_check(not ScoringModel.evaluate(null, crop).errors.is_empty(), "Null harvest rejected")
	_check(not ScoringModel.evaluate(harvest, null).errors.is_empty(), "Null crop rejected")

	crop.base_score = -1
	_check(not ScoringModel.evaluate(harvest, crop).errors.is_empty(), "Negative base score rejected")

	if _failures.is_empty():
		print("SCORING_MODEL_PASS")
		quit(0)
	else:
		for failure in _failures:
			printerr("FAIL: " + failure)
		quit(1)

func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)
