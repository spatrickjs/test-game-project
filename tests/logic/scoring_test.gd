extends SceneTree
## Tests the GameStateManager score-based win/lose flow and per-crop tally.

var _failures: PackedStringArray = PackedStringArray()

func _initialize() -> void:
	_run.call_deferred()

func _make_receipt(crop_type: int, score: float) -> HarvestResult:
	var r := HarvestResult.new()
	r.success = true
	r.crop_type = crop_type
	r.score = score
	return r

func _run() -> void:
	var game := GameStateManager.new()
	game.score_goal = 300
	game.turn_limit = 5

	game.record_harvest(_make_receipt(SimulationEnums.CropType.RICE, 100.0))
	_check(game.total_score == 0.0 and game.current_state == GameStateManager.State.MENU, "Harvests ignored before game starts")

	game.start_game()
	_check(game.total_score == 0.0 and game.harvest_count == 0 and game.crop_tally.is_empty() and game.is_playing(), "Start resets score and tally")

	game.record_harvest(_make_receipt(SimulationEnums.CropType.RICE, 100.0))
	_check(game.total_score == 100.0 and game.harvest_count == 1, "First harvest adds score")
	game.record_harvest(_make_receipt(SimulationEnums.CropType.CORN, 120.0))
	_check(game.total_score == 220.0 and game.harvest_count == 2, "Second harvest accumulates")
	var rice_tally: GameStateManager.CropTally = game.crop_tally[int(SimulationEnums.CropType.RICE)] as GameStateManager.CropTally
	var corn_tally: GameStateManager.CropTally = game.crop_tally[int(SimulationEnums.CropType.CORN)] as GameStateManager.CropTally
	_check(rice_tally != null and rice_tally.count == 1 and is_equal_approx(rice_tally.score, 100.0), "Rice tally recorded")
	_check(corn_tally != null and corn_tally.count == 1 and is_equal_approx(corn_tally.score, 120.0), "Corn tally recorded")

	var failed := HarvestResult.new()
	failed.success = false
	failed.score = 999.0
	game.record_harvest(failed)
	_check(game.total_score == 220.0 and game.harvest_count == 2, "Failed harvest ignored")

	game.record_harvest(_make_receipt(SimulationEnums.CropType.SUGARCANE, 100.0))
	_check(game.total_score == 320.0 and game.current_state == GameStateManager.State.VICTORY and not game.is_playing(), "Reaching score goal wins")
	game.record_harvest(_make_receipt(SimulationEnums.CropType.RICE, 100.0))
	_check(game.total_score == 320.0, "No score after victory")

	var game2 := GameStateManager.new()
	game2.score_goal = 100000
	game2.turn_limit = 3
	game2.start_game()
	game2.check_turn_limit(2)
	_check(game2.is_playing(), "Below turn limit stays playing")
	game2.check_turn_limit(3)
	_check(game2.current_state == GameStateManager.State.GAME_OVER and not game2.is_playing(), "Reaching turn limit loses")

	game.free()
	game2.free()
	if _failures.is_empty():
		print("SCORING_PASS")
		quit(0)
	else:
		for failure in _failures:
			printerr("FAIL: " + failure)
		quit(1)

func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)
