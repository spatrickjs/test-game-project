extends SceneTree
## Presentation tests for the Hoe and Shovel tool split.
## Covers the Hoe/Shovel Gherkin scenarios not already exercised by the queue
## and fence test suites: tool modes, labels, toggle, target highlighting,
## Hoe rejection messages, and the Shovel no-longer-digs invariant.
const GameplayFixture = preload("res://tests/logic/gameplay_test_fixture.gd")
const QueueDriver = preload("res://tests/logic/queued_action_test_driver.gd")
const Kind = SimulationEnums.FieldActionKind
const Terrain = SimulationEnums.TerrainType

var _failures: PackedStringArray = PackedStringArray()
var _scene: FieldPrototypePresenter
var _farming: FarmingController
var _world: FieldWorldView


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	_scene = (load("res://field_prototype.tscn") as PackedScene).instantiate() as FieldPrototypePresenter
	_scene.farming_controller.terrain_bands = [Terrain.DRY_SOIL, Terrain.PADDY_MUD, Terrain.GRASS]
	GameplayFixture.prepare(_scene, true)
	root.add_child(_scene)
	GameplayFixture.start(_scene)
	for frame: int in range(5):
		await process_frame
	_farming = _scene.farming_controller
	_world = _scene.world_view
	_world.farmer_agent.set_process(false)
	(_scene.get_node("HUD") as CanvasLayer).hide()

	var dry: Vector2i = Vector2i(0, 0)
	var dry2: Vector2i = Vector2i(1, 0)
	var grass: Vector2i = Vector2i(6, 0)

	# ------------------------------------------------------------------
	# Hoe selection: mode, label, toggle, and grass-only highlighting.
	# (Selecting the hoe / Deselecting the hoe)
	# ------------------------------------------------------------------
	_scene._on_hoe_pressed()
	_check(_scene._tool_mode == FieldPrototypePresenter.ToolMode.TOOL_HOE, "Hoe button sets TOOL_HOE")
	_check(_scene.selected_crop_label.text == "Tool: Hoe", "Hoe label reads Tool: Hoe")
	_check(_world.selection_overlay.eligible.has(grass), "Hoe highlights empty grass")
	_check(not _world.selection_overlay.eligible.has(dry), "Hoe does not highlight dry soil")
	# Hoe maps empty grass to DIG_GRASS (the shovel's former dig action).
	_check(_scene._make_action(grass, _farming.get_grid_snapshot().get_cell(grass)).kind == Kind.DIG_GRASS, "Hoe maps grass to DIG_GRASS")
	# Toggle off returns to INSPECT with the existing inspect label.
	_scene._on_hoe_pressed()
	_check(_scene._tool_mode == FieldPrototypePresenter.ToolMode.INSPECT, "Hoe toggles back to INSPECT")
	_check(_scene.selected_crop_label.text == "Mode: Inspect", "Inspect label reads Mode: Inspect")
	_check(_world.selection_overlay.eligible.is_empty(), "No tiles highlighted in inspect mode")

	# ------------------------------------------------------------------
	# Hoe rejects ineligible terrain with one message.
	# (Hoe rejects ineligible terrain: dry soil / a crop / a fence)
	# ------------------------------------------------------------------
	_check(_farming.action_error(_dig(dry)) == "Hoe requires empty grass.", "Hoe rejects dry soil")
	_check(_farming.action_error(_dig(Vector2i(-1, 0))) == "Choose a tile inside the field.", "Hoe out-of-bounds uses existing message")
	_farming.try_plant(dry2, SimulationEnums.CropType.CORN)
	_check(_farming.action_error(_dig(dry2)) == "Hoe requires empty grass.", "Hoe rejects a crop")
	# Fencing dry soil turns it to grass+fence; the Hoe still rejects fenced grass.
	_check(_farming.enqueue_action(_action(Kind.FENCE, dry)), "Fence queued for hoe-rejects-fence setup")
	_check(QueueDriver.finish(_scene), "Fence arrives for hoe-rejects-fence setup")
	await process_frame
	_check(_farming.action_error(_dig(dry)) == "Hoe requires empty grass.", "Hoe rejects a fence")

	# ------------------------------------------------------------------
	# Shovel keeps crop and fence removal; it no longer digs grass.
	# (Shovel does not dig grass / Removing a fence with the shovel)
	# ------------------------------------------------------------------
	_scene._on_remove_pressed()
	_check(_scene.selected_crop_label.text == "Tool: Shovel", "Shovel label reads Tool: Shovel")
	# Shovel on empty grass now maps to REMOVE_CROP (rejected), never DIG_GRASS.
	_check(_scene._make_action(grass, _farming.get_grid_snapshot().get_cell(grass)).kind == Kind.REMOVE_CROP, "Shovel maps grass to REMOVE_CROP, not DIG_GRASS")
	_check(_farming.action_error(_action(Kind.REMOVE_CROP, grass)) == "Choose a crop to remove.", "Shovel reports crop-required on grass")
	# Clicking grass with the shovel queues nothing and leaves the terrain unchanged.
	_scene._on_cell_clicked(grass)
	_check(not _farming.has_pending_actions(), "Shovel does not queue an action on grass")
	_check(_farming.get_grid_snapshot().get_cell(grass).terrain_type == Terrain.GRASS, "Shovel leaves grass terrain as GRASS")
	# Shovel still removes fences: fenced tile maps to REMOVE_FENCE.
	_check(_scene._make_action(dry, _farming.get_grid_snapshot().get_cell(dry)).kind == Kind.REMOVE_FENCE, "Shovel maps fenced tile to REMOVE_FENCE")
	# Shovel highlights crops and fences, not grass.
	_check(_world.selection_overlay.eligible.has(dry2) and _world.selection_overlay.eligible.has(dry), "Shovel highlights crops and fences")
	_check(not _world.selection_overlay.eligible.has(grass), "Shovel does not highlight grass")

	# ------------------------------------------------------------------
	# Hoe and Shovel are disabled outside gameplay.
	# (Hoe and Shovel are disabled outside gameplay)
	# ------------------------------------------------------------------
	_scene._set_controls_enabled(false)
	_check(_scene.remove_button.disabled, "Shovel button disabled outside PLAYING")
	if _scene.hoe_button != null:
		_check(_scene.hoe_button.disabled, "Hoe button disabled outside PLAYING")
	_scene._set_controls_enabled(true)
	_check(not _scene.remove_button.disabled, "Shovel button re-enabled while playing")

	(_scene.get_node("HUD") as CanvasLayer).show()
	_scene.free()
	await process_frame
	for failure: String in _failures:
		printerr("FAIL: " + failure)
	if _failures.is_empty():
		print("HOE_AND_SHOVEL_PASS")
	quit(0 if _failures.is_empty() else 1)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _action(kind: SimulationEnums.FieldActionKind, target: Vector2i) -> FieldAction:
	var a: FieldAction = FieldAction.new()
	a.kind = kind
	a.target = target
	a.crop_type = SimulationEnums.CropType.CORN
	return a


func _dig(target: Vector2i) -> FieldAction:
	return _action(Kind.DIG_GRASS, target)


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)
