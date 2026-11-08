extends SceneTree
const GameplayFixture = preload("res://tests/logic/gameplay_test_fixture.gd")

var _failures: PackedStringArray = PackedStringArray()
var _intents: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var packed: PackedScene = load("res://field_prototype.tscn") as PackedScene
	var presenter: FieldPrototypePresenter = packed.instantiate() as FieldPrototypePresenter
	presenter.world_view.automatic_background_enabled = true # Optional fill coverage fixture.
	if presenter.world_view.background_fill_layer == null:
		presenter.world_view.background_fill_layer = TileMapLayer.new()
		presenter.world_view.add_child(presenter.world_view.background_fill_layer)
	GameplayFixture.prepare(presenter, false)
	root.add_child(presenter)
	GameplayFixture.start(presenter)
	for frame: int in range(5):
		await process_frame
	var view: FieldWorldView = presenter.world_view
	view.debug_clicks = false
	view.cell_clicked.connect(func(_cell: Vector2i) -> void: _intents += 1)
	var grid: FieldGridState = presenter.farming_controller.get_grid_snapshot()
	var terrain: TileMapLayer = view.terrain_layer
	var first: Vector2 = terrain.map_to_local(Vector2i.ZERO)
	var last: Vector2 = terrain.map_to_local(Vector2i(grid.width - 1, grid.height - 1))
	var geometric_center: Vector2 = terrain.to_global((first + last) * 0.5)
	var reserved: float = clampf(view.hud_reserved_height, 0.0, float(root.size.y) * 0.45)
	var projected_center: Vector2 = view.camera.get_canvas_transform() * geometric_center
	_check(projected_center.is_equal_approx(Vector2(float(root.size.x) * 0.5, (float(root.size.y) - reserved) * 0.5)), "Playable diamond center excludes atlas padding and sits above bottom HUD")
	var bottom_point: Vector2 = terrain.to_global(last + Vector2(0, float(terrain.tile_set.tile_size.y) * 0.5))
	_check((view.camera.get_canvas_transform() * bottom_point).y <= float(root.size.y) - reserved - view.camera_margin_pixels + 0.01, "Bottom diamond corner fits above reserved HUD space")
	var original_center: Vector2 = view.camera.global_position
	view.camera_center_offset = Vector2(300, 200)
	view.frame_field()
	_check(view.camera.global_position.is_equal_approx(original_center + view.camera_center_offset), "Inspector offset adjusts world-space camera center")
	view.pan_camera(Vector2(10000, 10000))
	_check(view.camera.global_position.is_equal_approx(original_center + view.camera_center_offset), "Clamping uses the adjusted overview center")
	for corner: Vector2 in [Vector2.ZERO, Vector2(root.size.x, 0), Vector2(root.size), Vector2(0, root.size.y)]:
		var coords: Vector2i = view.get_cell_at_viewport_position(corner)
		_check(terrain.get_cell_source_id(coords) >= 0 or view.background_fill_layer.get_cell_source_id(coords) >= 0, "Cosmetic terrain covers shifted viewport corners")
	view.camera_center_offset = Vector2.ZERO
	view.frame_field()
	var center: Vector2 = view.camera.global_position
	var minimum: float = view.min_zoom
	var viewport_center: Vector2 = Vector2(root.size) * 0.5
	var hud: CanvasLayer = presenter.get_node("HUD") as CanvasLayer
	hud.hide()
	await process_frame
	_check(not view.is_processing_input(), "No raw input processing")
	view.pan_camera(Vector2(10000.0, -10000.0))
	_check(view.camera.global_position.is_equal_approx(center), "Overview pan is locked")
	var focal: Vector2 = viewport_center + Vector2(80.0, -40.0)
	var expected_focal_world: Vector2 = view.camera.get_canvas_transform().affine_inverse() * focal
	view.apply_zoom_ratio(2.0, focal)
	_check(view.camera.global_position.is_equal_approx(center + (focal - viewport_center) * (1.0 / minimum - 1.0 / (minimum * 2.0))), "Focal offset formula")
	_check((view.camera.get_canvas_transform().affine_inverse() * focal).is_equal_approx(expected_focal_world), "World point stays under focal position")
	var before_pan: Vector2 = view.camera.global_position
	view.pan_camera(Vector2(24.0, -18.0))
	_check(view.camera.global_position.is_equal_approx(before_pan - Vector2(24.0, -18.0) / view.camera.zoom.x), "Pan is inverse zoom scaled")
	view.apply_zoom_ratio(100.0)
	var extent: Vector2 = Vector2(root.size) * 0.5 * (1.0 / minimum - 1.0 / view.max_zoom)
	for direction: Vector2 in [Vector2.ONE, -Vector2.ONE, Vector2(1.0, -1.0), Vector2(-1.0, 1.0)]:
		view.pan_camera(-direction * 100000.0)
		_check(view.camera.global_position.is_equal_approx(center + direction * extent), "All footprint corners reachable and clamped")
	view.apply_zoom_ratio(0.00001, focal)
	_check(view.camera.global_position.is_equal_approx(center), "Zoom out returns exactly to default center")
	# Native PC drag defers selection until release and suppresses moved clicks.
	view.apply_zoom_ratio(2.0)
	before_pan = view.camera.global_position
	_mouse(viewport_center, true)
	_check(_intents == 0, "PC press has no immediate tile action")
	_motion(viewport_center + Vector2(30.0, 20.0))
	_mouse(viewport_center + Vector2(30.0, 20.0), false)
	_check(view.camera.global_position.is_equal_approx(before_pan - Vector2(30.0, 20.0) / view.camera.zoom.x), "Native mouse drag pans")
	_check(_intents == 0, "PC pan suppresses tile selection")
	view.frame_field()
	for emulate: bool in [false, true]:
		Input.emulate_mouse_from_touch = emulate
		view.apply_zoom_ratio(2.0)
		before_pan = view.camera.global_position
		_touch(4, viewport_center, true)
		_drag(4, viewport_center + Vector2(5.0, 0.0))
		_check(view.camera.global_position.is_equal_approx(before_pan), "Subthreshold jitter does not pan")
		_drag(4, viewport_center + Vector2(25.0, 0.0))
		_check(view.camera.global_position.is_equal_approx(before_pan - Vector2(20.0, 0.0) / view.camera.zoom.x), "Single finger pan tracks movement after threshold")
		_touch(4, viewport_center + Vector2(25.0, 0.0), false)
		_check(_intents == 0, "Touch pan suppresses tile selection")
		view.frame_field()
		view.apply_zoom_ratio(1.8)
		var a: Vector2 = viewport_center + Vector2(-50.0, 0.0)
		var b: Vector2 = viewport_center + Vector2(50.0, 0.0)
		_touch(1, a, true)
		_touch(8, b, true)
		var world_under_midpoint: Vector2 = view.camera.get_canvas_transform().affine_inverse() * viewport_center
		_drag(8, b + Vector2(20.0, 0.0))
		var new_midpoint: Vector2 = viewport_center + Vector2(10.0, 0.0)
		_check((view.camera.get_canvas_transform().affine_inverse() * new_midpoint).is_equal_approx(world_under_midpoint), "Pinch anchors and translates midpoint together")
		_drag(1, a + Vector2(20.0, 0.0))
		_check(is_equal_approx(view.camera.zoom.x, minimum * 1.8), "Parallel two-finger movement restores distance zoom")
		_touch(1, a + Vector2(20.0, 0.0), false)
		_touch(8, b + Vector2(20.0, 0.0), false)
		_check(_intents == 0, "Pinch never selects")
		view.frame_field()
	# Native UI routes and fallback touch guards, with emulation on and off.
	hud.show()
	presenter.tile_inspector.hide()
	await process_frame
	_check(presenter.camera_zoom_button != null, "Persistent camera action is wired")
	_check(presenter.camera_zoom_button.owner == presenter, "Camera action has saved scene ownership")
	_check(presenter.hud_panel.mouse_filter == Control.MOUSE_FILTER_STOP, "HUD panel stops input")
	_check(not presenter.hud_panel.mouse_force_pass_scroll_events, "HUD blocks wheel pass-through")
	var button_point: Vector2 = presenter.camera_zoom_button.get_global_rect().get_center()
	Input.emulate_mouse_from_touch = true
	_touch(0, button_point, true)
	_touch(0, button_point, false)
	_check(is_equal_approx(view.camera.zoom.x, minimum * 1.8), "One-handed HUD touch zooms to inspection level")
	_check(presenter.camera_zoom_button.text == "Reset view", "Button explains reset action")
	_touch(0, button_point, true)
	_touch(0, button_point, false)
	_check(is_equal_approx(view.camera.zoom.x, minimum), "One-handed HUD touch resets overview")
	_check(view.camera.global_position.is_equal_approx(center), "Reset restores default center")
	_check(_intents == 0, "HUD action never emits tile intents")
	for emulate: bool in [false, true]:
		Input.emulate_mouse_from_touch = emulate
		view.apply_zoom_ratio(2.0)
		before_pan = view.camera.global_position
		var zoom_before: Vector2 = view.camera.zoom
		# Blank area inside the panel must block as well as buttons.
		var panel_point: Vector2 = presenter.hud_panel.get_global_rect().position + Vector2(5.0, 5.0)
		_touch(0, panel_point, true)
		_drag(0, viewport_center)
		_touch(0, viewport_center, false)
		# UI-first order must also quarantine the second finger through release.
		_touch(6, panel_point, true)
		_touch(9, viewport_center, true)
		_drag(9, viewport_center + Vector2(40.0, 0.0))
		_touch(6, panel_point, false)
		_touch(9, viewport_center + Vector2(40.0, 0.0), false)
		_check(view.camera.global_position.is_equal_approx(before_pan), "UI-first gesture blocks camera")
		_touch(1, viewport_center, true)
		_touch(2, panel_point, true)
		_drag(1, viewport_center + Vector2(40.0, 20.0))
		_touch(2, panel_point, false)
		_touch(1, viewport_center + Vector2(40.0, 20.0), false)
		_check(view.camera.global_position.is_equal_approx(before_pan) and view.camera.zoom == zoom_before, "HUD fingers and UI-origin drag cannot pan or pinch")
		_touch(0, viewport_center, true)
		_drag(0, panel_point)
		_touch(0, panel_point, false)
		_check(view.camera.global_position.is_equal_approx(before_pan), "Dragging into UI cancels world gesture")
		_wheel(panel_point)
		_mouse(panel_point, true)
		_motion(viewport_center)
		_mouse(viewport_center, false)
		_check(view.camera.global_position.is_equal_approx(before_pan) and view.camera.zoom == zoom_before, "UI blocks wheel and mouse drag")
		_check(_intents == 0, "UI crossings emit no tile intents")
		view.frame_field()
	Input.emulate_mouse_from_touch = false
	# Stationary native clicks/taps remain immediate on release, even with tiny jitter.
	hud.hide()
	await process_frame
	var tile_point: Vector2 = view.terrain_layer.get_global_transform_with_canvas() * view.terrain_layer.map_to_local(Vector2i(4, 3))
	_touch(5, tile_point, true)
	_drag(5, tile_point + Vector2(2.0, 0.0))
	_touch(5, tile_point + Vector2(2.0, 0.0), false)
	_check(_intents == 1, "Small jitter remains a single tap")
	_mouse(tile_point, true)
	_mouse(tile_point, false)
	_check(_intents == 2, "PC stationary click acts once on release")
	# Resize re-establishes a valid footprint and clears gestures.
	view.apply_zoom_ratio(2.0)
	root.size = Vector2i(900, 600)
	for frame: int in range(4):
		await process_frame
	_check(is_equal_approx(view.camera.zoom.x, view.min_zoom), "Resize restores new overview")
	var resized_center: Vector2 = view.camera.global_position
	view.pan_camera(Vector2(10000.0, 0.0))
	_check(view.camera.global_position.is_equal_approx(resized_center), "New overview remains locked")
	presenter.queue_free()
	await process_frame
	if _failures.is_empty():
		print("CAMERA_UX_PASS")
		quit(0)
	else:
		for failure: String in _failures:
			printerr("FAIL: " + failure)
		quit(1)

func _touch(index: int, position: Vector2, pressed: bool) -> void:
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	root.push_input(event, true)

func _drag(index: int, position: Vector2) -> void:
	var event: InputEventScreenDrag = InputEventScreenDrag.new()
	event.index = index
	event.position = position
	root.push_input(event, true)

func _mouse(position: Vector2, pressed: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	root.push_input(event, true)

func _motion(position: Vector2) -> void:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = position
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(event, true)

func _wheel(position: Vector2) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = position
	event.button_index = MOUSE_BUTTON_WHEEL_UP
	event.pressed = true
	root.push_input(event, true)

func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)
