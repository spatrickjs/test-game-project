extends SceneTree

const Fixture = preload("res://tests/presentation/inspector_test_fixture.gd")
var _failures: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var bounds := Rect2(16, 16, 1248, 688)
	var desired := Vector2(300, 500)
	var left := TileInspectorView.popup_rect(Vector2(100, 350), bounds, desired, 16, [])
	var right := TileInspectorView.popup_rect(Vector2(1180, 350), bounds, desired, 16, [])
	_check(left.position.x > 100, "Left tile opens right")
	_check(right.end.x < 1180, "Right tile opens left")
	for target: Vector2 in [Vector2(16, 16), Vector2(1264, 16), Vector2(16, 704), Vector2(1264, 704), Vector2(-400, 900), Vector2(1700, -200)]:
		_check(bounds.encloses(TileInspectorView.popup_rect(target, bounds, desired, 16, [])), "Edge popup stays inside viewport")
	var obstruction := Rect2(600, 16, 320, 688)
	var avoided := TileInspectorView.popup_rect(Vector2(580, 350), bounds, desired, 16, [obstruction])
	_check(not avoided.intersects(obstruction), "Popup chooses free side around HUD")
	var narrow := Rect2(16, 16, 328, 608)
	var bottom := TileInspectorView.popup_rect(Vector2(180, 300), narrow, desired, 16, [])
	_check(narrow.encloses(bottom) and is_equal_approx(bottom.end.y, narrow.end.y), "Narrow viewport uses bottom panel")
	var view: TileInspectorView = Fixture.create()
	root.add_child(view)
	var grid := FieldGridState.new()
	grid.initialize(1, 1, AbioticState.new())
	var cell := grid.get_cell(Vector2i.ZERO)
	cell.has_crop = true
	cell.crop_type = SimulationEnums.CropType.RICE
	cell.susceptible_fraction = 0.75
	cell.infected_fraction = 0.25
	var crop: CropData = load("res://src/data/resources/rice_data.tres")
	view.display_cell(cell, crop)
	view.place_near_tile(Vector2(100, 350), [])
	await process_frame
	_check(view.susceptible_bar.value == 75.0 and view.infected_bar.value == 25.0, "Bars retain exact snapshot values during animation")
	_check(view.infected_label.text.contains("25.0%"), "Percentage remains readable in label")
	_check(view.infected_bar.custom_minimum_size.y == 16.0, "Bars have consistent height")
	var before: Vector2 = view.position
	view.place_near_tile(Vector2(1180, 350), [])
	_check(view.position != before, "Camera movement can reposition open popup")
	await process_frame
	var press := InputEventMouseButton.new()
	press.position = view.close_button.get_global_rect().get_center()
	press.global_position = press.position
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	root.push_input(press, true)
	var release := press.duplicate() as InputEventMouseButton
	release.pressed = false
	root.push_input(release, true)
	_check(not view.visible, "Close control works through viewport input")
	cell.has_crop = false
	view.display_cell(cell, null)
	_check(not view.infected_bar.visible and view.crop_name_label.text == "No crop", "Empty tile hides percentage bars")
	view.clear_display()
	view.free()
	for failure: String in _failures:
		print("FAIL: ", failure)
	print("TILE_INSPECTOR_POPUP_PASS" if _failures.is_empty() else "TILE_INSPECTOR_POPUP_FAIL")
	quit(0 if _failures.is_empty() else 1)
