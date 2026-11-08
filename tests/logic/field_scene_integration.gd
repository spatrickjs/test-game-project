extends SceneTree
const GameplayFixture = preload("res://tests/logic/gameplay_test_fixture.gd")
const InspectorFixture = preload("res://tests/presentation/inspector_test_fixture.gd")
const QueueDriver = preload("res://tests/logic/queued_action_test_driver.gd")
## Exercises the user's Editor-authored scene through real viewport input.
## Does not modify or save the scene or any resources.

var _failures: PackedStringArray = PackedStringArray()
var _intent_count: int = 0
var _close_count: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var packed: PackedScene = load("res://field_prototype.tscn") as PackedScene
	if packed == null:
		_check(false, "Scene failed to load")
		_finish()
		return
	var presenter: FieldPrototypePresenter = packed.instantiate() as FieldPrototypePresenter
	# The user assembles the real inspector in the Editor; inject a test-only
	# fixture until that scene node is saved. Never modify the scene on disk.
	if presenter.tile_inspector == null:
		presenter.tile_inspector = InspectorFixture.create()
		presenter.get_node("HUD").add_child(presenter.tile_inspector)
	# Test-authored layout: runtime must preserve these editor-style settings.
	presenter.hud_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	presenter.hud_panel.position = Vector2(12.0, 12.0)
	presenter.hud_panel.size = Vector2(360.0, 240.0)
	presenter.tile_inspector.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	presenter.tile_inspector.position = Vector2(800.0, 12.0)
	presenter.tile_inspector.size = Vector2(340.0, 560.0)
	GameplayFixture.prepare(presenter, true)
	root.add_child(presenter)
	GameplayFixture.start(presenter)
	for frame: int in range(5):
		await process_frame
	var farming: FarmingController = presenter.farming_controller
	var view: FieldWorldView = presenter.world_view
	_check(farming.is_initialized(), "Farming initialized")
	_check(view.is_processing_unhandled_input(), "World input enabled")
	_check(presenter.hud_panel.mouse_filter == Control.MOUSE_FILTER_STOP, "HUD panel blocks world input")
	_check(presenter.hud_panel.position == Vector2(12.0, 12.0), "Authored HUD position preserved")
	_check(not presenter.rice_button.button_pressed, "Starts with no planting selection")
	var inspect_position: Vector2i = _find_empty(farming.get_grid_snapshot(), SimulationEnums.TerrainType.DRY_SOIL)
	_click(view.terrain_layer.get_global_transform_with_canvas() * view.terrain_layer.map_to_local(inspect_position))
	await process_frame
	_check(presenter.tile_inspector.visible, "Inspect click opens panel")
	_check(not farming.get_grid_snapshot().get_cell(inspect_position).has_crop, "Inspection does not plant")
	_check(presenter.tile_inspector.crop_name_label.text == "No crop", "Empty tile text")
	# Reconnecting twice must not multiply intents, planting, or turns.
	presenter._connect_signals()
	presenter._connect_signals()
	view.cell_clicked.connect(_count_intent)
	presenter.tile_inspector.close_requested.connect(func() -> void: _close_count += 1)
	_click(presenter.rice_button.get_global_rect().get_center())
	await process_frame
	_check(presenter.rice_button.button_pressed and not presenter.tile_inspector.visible, "Plant mode closes inspector and highlights crop")
	_check(_intent_count == 0, "HUD click does not reach the field")
	var rice_position: Vector2i = _find_empty(farming.get_grid_snapshot(), SimulationEnums.TerrainType.PADDY_MUD)
	var viewport_position: Vector2 = (
		view.terrain_layer.get_global_transform_with_canvas()
		* view.terrain_layer.map_to_local(rice_position)
	)
	_check(view.get_cell_at_viewport_position(viewport_position) == rice_position, "Isometric/camera coordinate conversion")
	_click(viewport_position)
	_check(not farming.get_grid_snapshot().get_cell(rice_position).has_crop, "Planting is deferred until arrival")
	_check(QueueDriver.finish(presenter), "Farmer completes native planting")
	await process_frame
	var planted: FieldCellState = farming.get_grid_snapshot().get_cell(rice_position)
	_check(_intent_count == 1, "One native click emits one intent")
	_check(planted.has_crop and planted.crop_type == SimulationEnums.CropType.RICE, "HUD-selected rice planted by viewport click")
	var displayed: FieldGridState = view.crop_overlay.get("_snapshot") as FieldGridState
	_check(displayed != null and displayed.get_cell(rice_position).has_crop, "Overlay snapshot updated after planting")
	_click(presenter.next_turn_button.get_global_rect().get_center())
	await process_frame
	_check(presenter.turn_controller.turn_index == 1, "Next Turn delivered exactly once")
	_check(_intent_count == 1, "Next Turn button does not emit a planting intent")
	_check(farming.get_grid_snapshot().get_cell(rice_position).growth_elapsed_ticks == 1, "Growth advanced")
	displayed = view.crop_overlay.get("_snapshot") as FieldGridState
	_check(displayed.get_cell(rice_position).growth_elapsed_ticks == 1, "Overlay snapshot updated after turn")
	rice_position = _find_empty(farming.get_grid_snapshot(), SimulationEnums.TerrainType.PADDY_MUD)
	viewport_position = view.terrain_layer.get_global_transform_with_canvas() * view.terrain_layer.map_to_local(rice_position)
	_click(viewport_position, -1)
	_check(QueueDriver.finish(presenter), "Farmer completes emulated planting")
	await process_frame
	_check(_intent_count == 2, "Emulated mouse click accepted once")
	_check(farming.get_grid_snapshot().get_cell(rice_position).has_crop, "Emulated click plants selected crop")
	_click(presenter.rice_button.get_global_rect().get_center())
	await process_frame
	_check(not presenter.rice_button.button_pressed, "Clicking selected crop returns to Inspect mode")
	_click(viewport_position)
	await process_frame
	_check(presenter.tile_inspector.visible, "Planted crop can be inspected")
	_check(presenter.tile_inspector.growth_label.text.contains("0 /"), "Inspector displays planting growth")
	var intents_before_panel: int = _intent_count
	_click(presenter.tile_inspector.get_global_rect().get_center())
	await process_frame
	_check(_intent_count == intents_before_panel, "Inspector panel blocks world clicks")
	_click(presenter.next_turn_button.get_global_rect().get_center())
	await process_frame
	_check(presenter.tile_inspector.growth_label.text.contains("1 /"), "Turn refreshes inspected crop")
	_click(presenter.tile_inspector.close_button.get_global_rect().get_center())
	await process_frame
	_check(not presenter.tile_inspector.visible, "Close button hides inspector")
	_check(_close_count == 1, "Close button emits close_requested exactly once")
	_click(presenter.next_turn_button.get_global_rect().get_center())
	await process_frame
	_check(not presenter.tile_inspector.visible, "A closed inspector stays closed after turns")
	var diagnostic_cell: FieldCellState = farming.get_grid_snapshot().get_cell(rice_position)
	diagnostic_cell.susceptible_fraction = 1.5
	diagnostic_cell.has_active_disease = true
	presenter.tile_inspector.display_cell(diagnostic_cell, farming.crop_database.get_crop(diagnostic_cell.crop_type))
	_check(presenter.tile_inspector.susceptible_label.text.contains("INVALID"), "Invalid fraction is flagged")
	_check(not presenter.tile_inspector.susceptible_bar.visible, "Invalid fraction is not clamped into a misleading bar")
	_check(diagnostic_cell.susceptible_fraction == 1.5, "Inspector does not mutate snapshot")
	_check(presenter.tile_inspector.disease_label.text.contains("Unknown disease"), "Missing disease definition fallback")
	var disease: DiseaseData = DiseaseData.new()
	disease.disease_id = diagnostic_cell.active_disease_id
	disease.display_name = "Test disease"
	presenter.tile_inspector.disease_database = DiseaseDatabase.new()
	presenter.tile_inspector.disease_database.diseases.append(disease)
	presenter.tile_inspector.display_cell(diagnostic_cell, farming.crop_database.get_crop(diagnostic_cell.crop_type))
	_check(presenter.tile_inspector.disease_label.text.contains("Test disease"), "Active disease name resolves")
	var empty_grass: FieldCellState = FieldCellState.new()
	presenter.tile_inspector.display_cell(empty_grass, null)
	_check(presenter.tile_inspector.soil_ph_label.text == "No soil data", "Grass has no soil display")
	_check(presenter.tile_inspector.state_label.text.contains("Not applicable"), "Empty tile epidemic values are not applicable")
	# Exercise authored right anchoring: resize may change position, not offsets.
	presenter.tile_inspector.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	presenter.tile_inspector.offset_left = -352.0
	presenter.tile_inspector.offset_right = -12.0
	presenter.tile_inspector.offset_top = 12.0
	presenter.tile_inspector.offset_bottom = 572.0
	root.content_scale_size = Vector2i(480, 480)
	root.size = Vector2i(480, 480)
	for frame: int in range(3):
		await process_frame
	_check(presenter.tile_inspector.anchor_right == 1.0 and presenter.tile_inspector.anchor_left == 1.0, "Viewport resize preserves authored anchors")
	_check(is_equal_approx(presenter.tile_inspector.offset_right, -12.0) and is_equal_approx(presenter.tile_inspector.offset_left, -352.0), "Viewport resize preserves authored offsets")
	_check(presenter.tile_inspector.scroll_container.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO, "Small viewport content is scrollable")
	presenter.queue_free()
	await process_frame
	_finish()


func _click(position: Vector2, device_id: int = 0) -> void:
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.position = position
	press.global_position = position
	press.device = device_id
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	root.push_input(press, true)
	var release: InputEventMouseButton = press.duplicate() as InputEventMouseButton
	release.pressed = false
	root.push_input(release, true)


func _find_empty(grid: FieldGridState, terrain: SimulationEnums.TerrainType) -> Vector2i:
	for y: int in range(grid.height):
		for x: int in range(grid.width):
			var cell: FieldCellState = grid.get_cell(Vector2i(x, y))
			if cell.terrain_type == terrain and not cell.has_crop:
				return cell.coordinates
	return Vector2i(-1, -1)


func _count_intent(_coordinates: Vector2i) -> void:
	_intent_count += 1


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)


func _finish() -> void:
	if _failures.is_empty():
		print("FIELD_SCENE_INTEGRATION_PASS")
		quit(0)
	else:
		for failure: String in _failures:
			printerr("FAIL: " + failure)
		quit(1)
