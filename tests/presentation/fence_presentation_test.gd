extends SceneTree
## Presentation tests for the Fence Treatment Method.
## Validates Requirement 9 (presentation) and shovel drag (Requirement 6.5).
const GameplayFixture = preload("res://tests/logic/gameplay_test_fixture.gd")
const QueueDriver = preload("res://tests/logic/queued_action_test_driver.gd")
const Kind = SimulationEnums.FieldActionKind

var _failures: PackedStringArray = PackedStringArray()
var _scene: FieldPrototypePresenter
var _farming: FarmingController
var _world: FieldWorldView


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	_scene = (load("res://field_prototype.tscn") as PackedScene).instantiate() as FieldPrototypePresenter
	_scene.farming_controller.terrain_bands = [
		SimulationEnums.TerrainType.DRY_SOIL,
		SimulationEnums.TerrainType.PADDY_MUD,
		SimulationEnums.TerrainType.GRASS,
	]
	GameplayFixture.prepare(_scene, true)
	root.add_child(_scene)
	GameplayFixture.start(_scene)
	for frame: int in range(5):
		await process_frame
	_farming = _scene.farming_controller
	_world = _scene.world_view
	_world.farmer_agent.set_process(false)
	(_scene.get_node("HUD") as CanvasLayer).hide()

	var snap: FieldGridState = _farming.get_grid_snapshot()
	var dry: Vector2i = Vector2i(0, 0)
	var dry2: Vector2i = Vector2i(1, 0)
	var grass: Vector2i = Vector2i(6, 0)
	var grass2: Vector2i = Vector2i(7, 0)
	var crop: Vector2i = Vector2i(0, 0)

	# ------------------------------------------------------------------
	# Fence layer configuration.
	# ------------------------------------------------------------------
	_check(_world.fence_layer != null, "FenceLayer assigned in scene")
	_check(_world.fence_visual != null, "FenceVisual assigned in scene")
	# Fence layer TileSet is independent of terrain and crop TileSets.
	_check(_world.fence_layer.tile_set != _world.terrain_layer.tile_set, "Fence TileSet independent of terrain")
	_check(_world.fence_layer.tile_set != _world.crop_layer.tile_set, "Fence TileSet independent of crops")

	# validate_fence_visual reports no errors when configured.
	var fv_errors: PackedStringArray = _world.validate_fence_visual()
	_check(fv_errors.is_empty(), "validate_fence_visual clean: %s" % "\n".join(fv_errors))

	# HUD button icon and map tile come from the same atlas region.
	var icon: Texture2D = _world.get_fence_icon()
	_check(icon != null, "get_fence_icon returns a texture when configured")

	# Fence button exists and is a toggle.
	_check(_scene.fence_button != null, "Fence button saved and wired")
	_check(_scene.fence_button.toggle_mode, "Fence button is toggle-mode")

	# ------------------------------------------------------------------
	# FenceLayer draws tiles on fenced cells and erases them on removal.
	# ------------------------------------------------------------------
	# Initially, no fence tiles.
	_check(_world.fence_layer.get_used_cells().is_empty(), "FenceLayer starts empty")
	# Queue a fence on dry soil and drive the farmer.
	_check(_farming.enqueue_action(_action(Kind.FENCE, dry)), "Fence enqueued for presentation")
	_check(QueueDriver.finish(_scene), "Fence farmer arrives")
	await process_frame
	_check(_world.fence_layer.get_cell_source_id(dry) >= 0, "FenceLayer draws tile on fenced cell")
	_check(_world.grass_overlay_layer.get_cell_source_id(dry) == -1, "No grass tuft on fenced cell")

	# Remove the fence.
	_check(_farming.enqueue_action(_action(Kind.REMOVE_FENCE, dry)), "Remove fence enqueued")
	_check(QueueDriver.finish(_scene), "Remove fence farmer arrives")
	await process_frame
	_check(_world.fence_layer.get_cell_source_id(dry) == -1, "FenceLayer erases tile on fence removal")

	# ------------------------------------------------------------------
	# Inspector shows "Grass (fenced)".
	# ------------------------------------------------------------------
	# Fence dry soil (becomes grass).
	_check(_farming.enqueue_action(_action(Kind.FENCE, dry)), "Fence for inspector test")
	_check(QueueDriver.finish(_scene), "Fence for inspector arrives")
	await process_frame
	_scene._on_cell_clicked(dry)
	await process_frame
	_check(_scene.tile_inspector.terrain_label.text.find("(fenced)") >= 0, "Inspector shows Grass (fenced)")
	_scene.tile_inspector.clear_display()
	# Remove the fence from dry so it can be reused later.
	_check(_farming.enqueue_action(_action(Kind.REMOVE_FENCE, dry)), "Remove fence after inspector")
	_check(QueueDriver.finish(_scene), "Remove fence after inspector arrives")
	await process_frame

	# ------------------------------------------------------------------
	# Fence button toggles tool mode.
	# ------------------------------------------------------------------
	_scene._on_fence_pressed()
	_check(_scene._tool_mode == FieldPrototypePresenter.ToolMode.TOOL_FENCE, "Fence button sets TOOL_FENCE mode")
	_check(_scene.fence_button.button_pressed, "Fence button pressed in tool mode")
	# Eligibility highlighting includes dry soil (not fenced).
	_check(_world.selection_overlay.eligible.has(dry2), "Fence tool highlights eligible tiles")
	# Click to queue a fence.
	_click_cell(dry2)
	_check(_farming.has_pending_actions(), "Fence tool click enqueues action")
	_farming.cancel_actions()
	# Exit fence mode.
	_scene._enter_inspect_mode()
	_check(not _scene.fence_button.button_pressed, "Fence button unpressed in inspect mode")

	# ------------------------------------------------------------------
	# Fence button is disabled outside PLAYING.
	# ------------------------------------------------------------------
	# Currently playing, so enabled.
	_check(not _scene.fence_button.disabled, "Fence button enabled while playing")
	# Simulate game over by disabling controls.
	_scene._set_controls_enabled(false)
	_check(_scene.fence_button.disabled, "Fence button disabled outside PLAYING")
	_scene._set_controls_enabled(true)

	# ------------------------------------------------------------------
	# Shovel drag from a fenced tile selects only fenced tiles.
	# ------------------------------------------------------------------
	# Fence two grass tiles.
	_check(_farming.enqueue_action(_action(Kind.FENCE, grass)), "Fence grass1")
	_check(QueueDriver.finish(_scene), "Fence grass1 arrives")
	_check(_farming.enqueue_action(_action(Kind.FENCE, grass2)), "Fence grass2")
	_check(QueueDriver.finish(_scene), "Fence grass2 arrives")
	await process_frame
	# Plant a crop on dry2 soil for the mixed-context test (dry was used earlier).
	_check(_farming.try_plant(dry2, SimulationEnums.CropType.CORN), "Crop planted for drag test")
	await process_frame
	# Shovel mode.
	_scene._on_remove_pressed()
	# Start drag on a fenced tile.
	_mouse(grass, true)
	_drag(grass2)
	# Crop tile should not be selected (different kind).
	_check(_world.selection_overlay.selected.has(grass) and _world.selection_overlay.selected.has(grass2), "Shovel drag selects fenced tiles")
	_check(not _world.selection_overlay.selected.has(dry2), "Shovel drag from fenced tile does not select crop tile")
	_mouse(grass2, false)
	_check(not _farming.get_queued_coordinates().has(dry2), "Crop not queued by fenced drag")
	_check(QueueDriver.finish(_scene), "Shovel drag (remove fence) completes")
	await process_frame
	# Fences removed.
	_check(not _farming.get_grid_snapshot().get_cell(grass).has_fence, "Fence grass1 removed by shovel drag")
	_check(not _farming.get_grid_snapshot().get_cell(grass2).has_fence, "Fence grass2 removed by shovel drag")

	# ------------------------------------------------------------------
	# Unassigned fence layer or visual is safe (null-safe).
	# ------------------------------------------------------------------
	var saved_layer: TileMapLayer = _world.fence_layer
	var saved_visual: FenceVisual = _world.fence_visual
	_world.fence_layer = null
	_world.fence_visual = null
	# render_fences must not crash and must not error.
	_world.render_fences(_farming.get_grid_snapshot())
	_check(_world.validate_fence_visual().is_empty(), "validate_fence_visual empty when unassigned")
	_check(_world.get_fence_icon() == null, "get_fence_icon null when unassigned")
	_world.fence_layer = saved_layer
	_world.fence_visual = saved_visual

	# Bad visual reports error.
	_world.fence_visual.source_id = 999
	var bad_errors: PackedStringArray = _world.validate_fence_visual()
	_check(not bad_errors.is_empty(), "validate_fence_visual reports bad source")
	_world.fence_visual.source_id = 0

	# ------------------------------------------------------------------
	# Play Again clears fences.
	# ------------------------------------------------------------------
	# Place a fence.
	_check(_farming.enqueue_action(_action(Kind.FENCE, dry)), "Fence before play again")
	_check(QueueDriver.finish(_scene), "Fence before play again arrives")
	await process_frame
	_check(_farming.get_grid_snapshot().get_cell(dry).has_fence, "Fence present before Play Again")
	# Trigger Play Again (reinitialize).
	_scene._on_play_again_pressed()
	await process_frame
	_check(not _farming.get_grid_snapshot().get_cell(dry).has_fence, "Play Again clears fences")
	_check(_world.fence_layer.get_used_cells().is_empty(), "FenceLayer empty after Play Again")

	(_scene.get_node("HUD") as CanvasLayer).show()
	_scene.free()
	await process_frame
	for failure: String in _failures:
		printerr("FAIL: " + failure)
	if _failures.is_empty():
		print("FENCE_PRESENTATION_PASS")
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


func _point(coords: Vector2i) -> Vector2:
	return _world.terrain_layer.get_global_transform_with_canvas() * _world.terrain_layer.map_to_local(coords)


func _click_cell(coords: Vector2i) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = _point(coords)
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	_world._unhandled_input(event)
	event.pressed = false
	_world._unhandled_input(event)


func _mouse(coords: Vector2i, pressed: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = _point(coords)
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	_world._unhandled_input(event)


func _drag(coords: Vector2i) -> void:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = _point(coords)
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	_world._unhandled_input(event)


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)
