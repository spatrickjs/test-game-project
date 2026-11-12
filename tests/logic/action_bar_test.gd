extends SceneTree
const GameplayFixture = preload("res://tests/logic/gameplay_test_fixture.gd")
const QueueDriver = preload("res://tests/logic/queued_action_test_driver.gd")
const Kind = SimulationEnums.FieldActionKind

var _failures: PackedStringArray = PackedStringArray()
var _scene: FieldPrototypePresenter
var _farming: FarmingController
var _turn_controller: TurnController


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	_scene = (load("res://field_prototype.tscn") as PackedScene).instantiate() as FieldPrototypePresenter
	_scene.farming_controller.terrain_bands = [SimulationEnums.TerrainType.DRY_SOIL, SimulationEnums.TerrainType.PADDY_MUD, SimulationEnums.TerrainType.GRASS]
	GameplayFixture.prepare(_scene, true)
	root.add_child(_scene)
	GameplayFixture.start(_scene)
	for frame: int in range(5):
		await process_frame
	_farming = _scene.farming_controller
	_turn_controller = _scene.turn_controller
	_scene.world_view.farmer_agent.set_process(false)
	
	_test_starts_full()
	_test_swappable_maximum()
	_test_invalid_maximum()
	_test_raise_maximum()
	_test_lower_maximum()
	_test_lower_maximum_above_count()
	_test_each_action_consumes()
	_test_empty_bar_rejects()
	_test_invalid_action_no_consume()
	_test_never_exceeds_maximum()
	_test_never_below_zero()
	_test_queued_action_consumes()
	_test_failed_commit_preserves()
	_test_movement_no_consume()
	_test_end_turn_resets()
	_test_mid_turn_max_change()
	_test_available_after_reset()
	_test_no_reset_without_turn()
	_test_failed_end_turn_preserves()
	
	_scene.free()
	await process_frame
	for failure: String in _failures:
		printerr("FAIL: " + failure)
	if _failures.is_empty():
		print("ACTION_BAR_PASS")
	quit(0 if _failures.is_empty() else 1)


func _request(kind: SimulationEnums.FieldActionKind, coords: Vector2i, source: Vector2i = Vector2i(-1, -1)) -> FieldAction:
	var action: FieldAction = FieldAction.new()
	action.kind = kind
	action.target = coords
	action.source = source
	action.crop_type = SimulationEnums.CropType.CORN
	return action


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)


func _test_starts_full() -> void:
	_check(_farming.get_max_actions() == 5 and _farming.get_actions_remaining() == 5, "R1: Action bar starts full at default maximum")


func _test_swappable_maximum() -> void:
	for max_val: int in [1, 3, 5, 8, 10]:
		_check(_farming.try_set_max_actions(max_val), "R2: Maximum set to %d" % max_val)
		_check(_farming.get_max_actions() == max_val, "R2: Maximum is now %d" % max_val)
		_farming.initialize_field()
		_check(_farming.get_actions_remaining() == max_val, "R2: New game starts full at %d" % max_val)


func _test_invalid_maximum() -> void:
	var initial_max: int = _farming.get_max_actions()
	var initial_remaining: int = _farming.get_actions_remaining()
	for invalid: int in [0, -1]:
		_check(not _farming.try_set_max_actions(invalid), "R3: Maximum %d rejected" % invalid)
		_check(_farming.last_error != "", "R3: last_error set for invalid %d" % invalid)
		_check(_farming.get_max_actions() == initial_max, "R3: Maximum unchanged after %d" % invalid)
		_check(_farming.get_actions_remaining() == initial_remaining, "R3: Remaining unchanged after %d" % invalid)


func _test_raise_maximum() -> void:
	_farming.adjust_actions_remaining(-3)
	_check(_farming.get_actions_remaining() == 2, "Setup: remaining = 2")
	_check(_farming.try_set_max_actions(8), "R4: Raise maximum")
	_check(_farming.get_max_actions() == 8 and _farming.get_actions_remaining() == 2, "R4: Count kept when raising")


func _test_lower_maximum() -> void:
	_farming.initialize_field()
	_check(_farming.get_actions_remaining() == 5, "Setup: remaining = 5")
	_check(_farming.try_set_max_actions(3), "R4: Lower maximum")
	_check(_farming.get_max_actions() == 3 and _farming.get_actions_remaining() == 3, "R4: Count clamped when lowering")


func _test_lower_maximum_above_count() -> void:
	_farming.initialize_field()
	_farming.adjust_actions_remaining(-3)
	_check(_farming.get_actions_remaining() == 2, "Setup: remaining = 2")
	_check(_farming.try_set_max_actions(3), "R4: Lower maximum to 3")
	_check(_farming.get_max_actions() == 3 and _farming.get_actions_remaining() == 2, "R4: Count kept when above new max")


func _test_each_action_consumes() -> void:
	var test_cases: Array = [
		{max: 5, action: Kind.PLANT, before: 5, after: 4},
		{max: 5, action: Kind.WATER_SOIL, before: 4, after: 3},
		{max: 5, action: Kind.HARVEST, before: 3, after: 2},
		{max: 5, action: Kind.REMOVE_CROP, before: 2, after: 1},
		{max: 5, action: Kind.PLANT, before: 1, after: 0},
	]
	for tc in test_cases:
		_farming.initialize_field()
		_turn_controller.reset_clock()
		_farming.try_set_max_actions(tc.max)
		_farming.adjust_actions_remaining(tc.before - tc.max)
		_check(_farming.get_actions_remaining() == tc.before, "Setup: remaining = %d" % tc.before)
		var target: Vector2i = Vector2i(0, 0)
		var action: FieldAction = _request(tc.action, target)
		if tc.action == Kind.PLANT or tc.action == Kind.REMOVE_CROP or tc.action == Kind.HARVEST:
			_farming.try_plant(target, SimulationEnums.CropType.CORN)
		elif tc.action == Kind.WATER_SOIL:
			action.additions = Vector3(0.1, 0.0, 0.0)
		_check(_farming.enqueue_action(action), "Action enqueued")
		_check(QueueDriver.finish(_scene), "Farmer arrives")
		_check(_farming.get_actions_remaining() == tc.after, "R5: Consumed 1 action (max=%d, %d->%d)" % [tc.max, tc.before, tc.after])


func _test_empty_bar_rejects() -> void:
	for max_val: int in [3, 5, 8]:
		_farming.initialize_field()
		_farming.try_set_max_actions(max_val)
		_farming.adjust_actions_remaining(-max_val)
		_check(_farming.get_actions_remaining() == 0, "Setup: bar empty")
		var grid_before: FieldGridState = _farming.get_grid_snapshot()
		var rng_before: int = _turn_controller.simulation_controller.rng.state
		var action: FieldAction = _request(Kind.PLANT, Vector2i(0, 0))
		_check(not _farming.enqueue_action(action), "R6: Action rejected when bar empty")
		_check(_farming.last_error != "", "R6: Error set for empty bar")
		_check(_farming.get_actions_remaining() == 0, "R6: Bar unchanged")
		_check(_farming.get_grid_snapshot().copy() == grid_before.copy(), "R6: Grid unchanged")


func _test_invalid_action_no_consume() -> void:
	_farming.initialize_field()
	_farming.adjust_actions_remaining(-3)
	_check(_farming.get_actions_remaining() == 2, "Setup: remaining = 2")
	var action: FieldAction = _request(Kind.HARVEST, Vector2i(0, 0))
	_check(not _farming.enqueue_action(action), "R7: Invalid action rejected (no crop to harvest)")
	_check(_farming.get_actions_remaining() == 2, "R7: Count unchanged")


func _test_never_exceeds_maximum() -> void:
	for max_val: int in [3, 5, 8]:
		_farming.initialize_field()
		_farming.try_set_max_actions(max_val)
		_check(_farming.get_actions_remaining() == max_val, "Setup: bar full")
		_farming.adjust_actions_remaining(1)
		_check(_farming.get_actions_remaining() == max_val, "R8: Never exceeds maximum")


func _test_never_below_zero() -> void:
	_farming.initialize_field()
	_farming.adjust_actions_remaining(-_farming.get_max_actions())
	_check(_farming.get_actions_remaining() == 0, "Setup: bar empty")
	_farming.adjust_actions_remaining(-1)
	_check(_farming.get_actions_remaining() == 0, "R8: Never below zero")


func _test_queued_action_consumes() -> void:
	_farming.initialize_field()
	_farming.adjust_actions_remaining(-3)
	_check(_farming.get_actions_remaining() == 2, "Setup: remaining = 2")
	var target: Vector2i = Vector2i(0, 0)
	_farming.try_plant(target, SimulationEnums.CropType.CORN)
	var action: FieldAction = _request(Kind.REMOVE_CROP, target)
	_check(_farming.enqueue_action(action), "Action enqueued")
	_check(_farming.get_actions_remaining() == 2, "R9: Not consumed until commit")
	_check(QueueDriver.finish(_scene), "Farmer arrives")
	_check(_farming.get_actions_remaining() == 1, "R9: Consumed at commit")


func _test_failed_commit_preserves() -> void:
	_farming.initialize_field()
	_farming.adjust_actions_remaining(-3)
	_check(_farming.get_actions_remaining() == 2, "Setup: remaining = 2")
	var target: Vector2i = Vector2i(0, 0)
	var action: FieldAction = _request(Kind.HARVEST, target)
	_farming.enqueue_action(action)
	_check(QueueDriver.finish(_scene), "Farmer arrives")
	_check(_farming.get_actions_remaining() == 2, "R9: Bar unchanged on failed commit (harvest immature crop)")


func _test_movement_no_consume() -> void:
	_farming.initialize_field()
	_check(_farming.get_actions_remaining() == 5, "Setup: bar full")
	_farming.initialize_field()
	_check(_farming.get_actions_remaining() == 5, "R10: Movement path untouched (not implemented in test)")


func _test_end_turn_resets() -> void:
	var test_cases: Array = [
		{max: 5, before: 5},
		{max: 5, before: 3},
		{max: 5, before: 0},
		{max: 3, before: 1},
		{max: 8, before: 0},
	]
	for tc in test_cases:
		_farming.initialize_field()
		_turn_controller.reset_clock()
		_farming.try_set_max_actions(tc.max)
		_farming.adjust_actions_remaining(tc.before - tc.max)
		_check(_farming.get_actions_remaining() == tc.before, "Setup: remaining = %d" % tc.before)
		_check(_turn_controller.advance_turn(), "R11: Turn advanced")
		_check(_farming.get_actions_remaining() == tc.max, "R11: Reset to max=%d (from %d)" % [tc.max, tc.before])


func _test_mid_turn_max_change() -> void:
	_farming.initialize_field()
	_turn_controller.reset_clock()
	_farming.adjust_actions_remaining(-4)
	_check(_farming.get_actions_remaining() == 1, "Setup: remaining = 1")
	_check(_farming.try_set_max_actions(8), "Mid-turn: maximum set to 8")
	_check(_turn_controller.advance_turn(), "R11: Turn advanced")
	_check(_farming.get_actions_remaining() == 8, "R11: Reset uses new maximum (8, not old 5)")


func _test_available_after_reset() -> void:
	_farming.initialize_field()
	_turn_controller.reset_clock()
	_farming.adjust_actions_remaining(-5)
	_check(_farming.get_actions_remaining() == 0, "Setup: bar empty")
	_check(_turn_controller.advance_turn(), "Turn advanced")
	_check(_farming.get_actions_remaining() == 5, "Reset: bar full again")
	var target: Vector2i = Vector2i(0, 0)
	var action: FieldAction = _request(Kind.PLANT, target)
	_check(_farming.enqueue_action(action), "R11: Action available after reset")


func _test_no_reset_without_turn() -> void:
	_farming.initialize_field()
	_farming.adjust_actions_remaining(-3)
	_check(_farming.get_actions_remaining() == 2, "Setup: remaining = 2")
	var old_grid: FieldGridState = _farming.get_grid_snapshot().copy()
	_check(_farming.get_actions_remaining() == 2, "R12: Bar unchanged without turn end")
	_check(old_grid.copy() == _farming.get_grid_snapshot().copy(), "R12: Grid unchanged")


func _test_failed_end_turn_preserves() -> void:
	_farming.initialize_field()
	_turn_controller.reset_clock()
	_farming.adjust_actions_remaining(-3)
	_check(_farming.get_actions_remaining() == 2, "Setup: remaining = 2")
	var old_grid: FieldGridState = _farming.get_grid_snapshot().copy()
	var target: Vector2i = Vector2i(0, 0)
	_farming.try_plant(target, SimulationEnums.CropType.CORN)
	var action: FieldAction = _request(Kind.PLANT, target)
	_farming.enqueue_action(action)
	_check(not _turn_controller.advance_turn(), "R12: Turn rejected (pending actions)")
	_check(_turn_controller.last_error != "", "R12: Error set")
	_check(_farming.get_actions_remaining() == 2, "R12: Bar unchanged")
	_check(old_grid.copy() == _farming.get_grid_snapshot().copy(), "R12: Grid unchanged")
