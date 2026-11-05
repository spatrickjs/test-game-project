extends SceneTree

var _failures: PackedStringArray = PackedStringArray()
var _intents: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var packed: PackedScene = load("res://field_prototype.tscn") as PackedScene
	var presenter: FieldPrototypePresenter = packed.instantiate() as FieldPrototypePresenter
	root.add_child(presenter)
	for frame: int in range(5):
		await process_frame
	var view: FieldWorldView = presenter.world_view
	view.debug_clicks = false
	view.cell_clicked.connect(func(_cell: Vector2i) -> void: _intents += 1)
	var baseline: float = view.camera.zoom.x
	var center: Vector2 = view.camera.global_position
	_check(view.camera.is_current(), "Saved scene camera is active")
	_check(is_equal_approx(view.min_zoom, baseline), "Default framing is minimum")
	_check(is_equal_approx(view.max_zoom, baseline * 2.5), "Maximum is relative to default")
	view.apply_zoom_ratio(100.0)
	_check(is_equal_approx(view.camera.zoom.x, view.max_zoom), "Upper clamp")
	view.camera.global_position += Vector2(50.0, 50.0)
	view.apply_zoom_ratio(0.0001)
	_check(is_equal_approx(view.camera.zoom.x, baseline), "Lower clamp")
	_check(view.camera.global_position == center, "Minimum restores default center")
	view.apply_zoom_ratio(NAN)
	view.apply_zoom_ratio(-1.0)
	_check(is_equal_approx(view.camera.zoom.x, baseline), "Invalid ratios ignored")
	# Keep native viewport routing but hide controls for field-only gestures.
	presenter.get_node("HUD").hide()
	await process_frame
	var point: Vector2 = view.terrain_layer.get_global_transform_with_canvas() * view.terrain_layer.map_to_local(Vector2i(4, 3))
	_wheel(point, MOUSE_BUTTON_WHEEL_UP)
	_check(is_equal_approx(view.camera.zoom.x, baseline * view.wheel_zoom_factor), "Native wheel zooms in")
	_wheel(point, MOUSE_BUTTON_WHEEL_DOWN)
	_check(is_equal_approx(view.camera.zoom.x, baseline), "Native wheel zooms out")
	for emulate: bool in [false, true]:
		Input.emulate_mouse_from_touch = emulate
		var before: int = _intents
		_touch(4, point, true)
		_check(_intents == before, "Touch press never selects")
		_touch(9, point + Vector2(100.0, 0.0), true)
		_drag(9, point + Vector2(200.0, 0.0))
		_check(is_equal_approx(view.camera.zoom.x, baseline * 2.0), "Pinch distance ratio doubles zoom")
		_drag(9, point + Vector2(1000.0, 0.0))
		_check(is_equal_approx(view.camera.zoom.x, view.max_zoom), "Pinch upper clamp")
		_drag(9, point + Vector2(1.0, 0.0))
		_check(is_equal_approx(view.camera.zoom.x, baseline), "Pinch lower clamp")
		_touch(9, point + Vector2(1.0, 0.0), false)
		_touch(4, point, false)
		_check(_intents == before, "All pinch releases suppress tile intents")
		_touch(7, point, true)
		_touch(7, point, false)
		_check(_intents == before + 1, "Single tap emits exactly once with arbitrary index")
		_touch(7, point, true)
		_drag(7, point + Vector2(50.0, 0.0))
		_drag(7, point)
		_touch(7, point, false)
		_check(_intents == before + 1, "Dragging out and back cancels tap")
		_touch(7, point, true)
		_touch(7, point, false, true)
		_check(_intents == before + 1, "Canceled touch suppresses tap")
		# A third finger invalidates the entire gesture until every finger lifts.
		_touch(1, point, true)
		_touch(2, point, true)
		_touch(3, point, true)
		_drag(2, point + Vector2(50.0, 0.0))
		_touch(1, point, false)
		_touch(2, point, false)
		_touch(3, point, false)
		_check(_intents == before + 1, "Three fingers and coincident points are safe")
	Input.emulate_mouse_from_touch = false
	# HUD-origin touch must not become a field tap when released over the field.
	presenter.get_node("HUD").show()
	await process_frame
	var before_hud: int = _intents
	_touch(0, presenter.next_turn_button.get_global_rect().get_center(), true)
	_touch(0, point, false)
	_check(_intents == before_hud, "HUD-origin touch does not select field")
	view.apply_zoom_ratio(2.0)
	view.frame_field()
	_check(is_equal_approx(view.camera.zoom.x, view.min_zoom), "Reframing resets zoom baseline")
	_check(view.camera.global_position == center, "Reframing preserves original center")
	presenter.queue_free()
	await process_frame
	if _failures.is_empty():
		print("CAMERA_ZOOM_PASS")
		quit(0)
	else:
		for failure: String in _failures:
			printerr("FAIL: " + failure)
		quit(1)

func _touch(index: int, position: Vector2, pressed: bool, canceled: bool = false) -> void:
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	event.canceled = canceled
	root.push_input(event, true)

func _drag(index: int, position: Vector2) -> void:
	var event: InputEventScreenDrag = InputEventScreenDrag.new()
	event.index = index
	event.position = position
	root.push_input(event, true)

func _wheel(position: Vector2, button: MouseButton) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = position
	event.button_index = button
	event.pressed = true
	root.push_input(event, true)

func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)
