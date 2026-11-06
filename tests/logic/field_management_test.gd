extends SceneTree
const QueueDriver = preload("res://tests/logic/queued_action_test_driver.gd")

var _failures: PackedStringArray = PackedStringArray()
var _changes: Array[Vector2i] = []
const PAYLOAD: Array[StringName] = [&"has_crop", &"crop_type", &"growth_elapsed_ticks", &"sir_state", &"removed_outcome", &"has_active_disease", &"active_disease_id", &"susceptible_fraction", &"exposed_fraction", &"infected_fraction", &"recovered_immune_fraction", &"dead_fraction"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var scene: FieldPrototypePresenter = (load("res://field_prototype.tscn") as PackedScene).instantiate() as FieldPrototypePresenter
	root.add_child(scene)
	for frame: int in range(5):
		await process_frame
	var farming: FarmingController = scene.farming_controller
	var world: FieldWorldView = scene.world_view
	_check(scene.remove_button != null and scene.transfer_button != null, "Tool controls saved and wired")
	if scene.remove_button == null or scene.transfer_button == null:
		scene.free()
		_finish()
		return
	var snapshot: FieldGridState = farming.get_grid_snapshot()
	var dry: Array[Vector2i] = _terrain_cells(snapshot, SimulationEnums.TerrainType.DRY_SOIL)
	var rice: Array[Vector2i] = _terrain_cells(snapshot, SimulationEnums.TerrainType.PADDY_MUD)
	var grass: Array[Vector2i] = _terrain_cells(snapshot, SimulationEnums.TerrainType.GRASS)
	farming.cell_changed.connect(func(coordinates: Vector2i) -> void: _changes.append(coordinates))
	# Native mouse clicks exercise HUD -> world input -> Presenter -> Logic.
	_click(scene.corn_button.get_global_rect().get_center())
	await process_frame
	_click_cell(world, dry[0])
	_check(not farming.get_grid_snapshot().get_cell(dry[0]).has_crop, "Native planting waits for arrival")
	_check(QueueDriver.finish(scene), "Plant queue completes")
	await process_frame
	_check(farming.get_grid_snapshot().get_cell(dry[0]).has_crop, "Native planting")
	_click(scene.next_turn_button.get_global_rect().get_center())
	await process_frame
	var before: FieldCellState = farming.get_grid_snapshot().get_cell(dry[0])
	var turn_before: String = scene.turn_label.text
	_click(scene.transfer_button.get_global_rect().get_center())
	await process_frame
	_check(not scene.corn_button.button_pressed and scene.transfer_button.button_pressed, "Move excludes Plant mode")
	_click_cell(world, dry[0])
	await process_frame
	_click_cell(world, grass[0])
	await process_frame
	_check(farming.get_grid_snapshot().get_cell(dry[0]).has_crop, "Invalid destination retains source")
	_changes.clear()
	_click_cell(world, dry[1])
	_check(farming.get_grid_snapshot().get_cell(dry[0]).has_crop and not farming.get_grid_snapshot().get_cell(dry[1]).has_crop, "Move waits for both visits")
	_check(QueueDriver.finish(scene), "Move queue completes")
	await process_frame
	var after: FieldGridState = farming.get_grid_snapshot()
	_check(not after.get_cell(dry[0]).has_crop and after.get_cell(dry[1]).has_crop, "Native move commits both endpoints")
	_compare_payload(before, after.get_cell(dry[1]))
	_check(_changes == [dry[0], dry[1]], "Exactly two post-commit change signals")
	_check(world.crop_layer.get_cell_source_id(dry[0]) == -1, "Old sprite erased")
	_check(world.crop_layer.get_cell_source_id(dry[1]) >= 0, "Destination sprite rendered")
	_check(scene.turn_label.text == turn_before, "Move does not advance turn")
	await _capture("moved")
	_click(scene.remove_button.get_global_rect().get_center())
	await process_frame
	_click_cell(world, dry[1])
	_check(farming.get_grid_snapshot().get_cell(dry[1]).has_crop, "Shovel waits for arrival")
	_check(QueueDriver.finish(scene), "Removal queue completes")
	await process_frame
	_check(not farming.get_grid_snapshot().get_cell(dry[1]).has_crop, "Native shovel removes crop")
	_check(world.crop_layer.get_cell_source_id(dry[1]) == -1, "Removed sprite erased")
	_check(scene.turn_label.text == turn_before, "Removal does not advance turn")
	await _capture("removed")
	# Valid mixed-compartment fixture: preserves every payload field exactly.
	_check(farming.try_plant(rice[0], SimulationEnums.CropType.RICE), "Rice fixture planted")
	var fixture: FieldGridState = farming.get_grid_snapshot()
	var infected: FieldCellState = fixture.get_cell(rice[0])
	infected.growth_elapsed_ticks = 3
	infected.has_active_disease = true
	infected.active_disease_id = SimulationEnums.DiseaseId.RICE_BLAST
	infected.sir_state = SimulationEnums.SIRState.I
	infected.susceptible_fraction = 0.1
	infected.exposed_fraction = 0.2
	infected.infected_fraction = 0.3
	infected.recovered_immune_fraction = 0.25
	infected.dead_fraction = 0.15
	fixture.get_cell(rice[0]).soil.soil_ph = 6.0
	fixture.get_cell(rice[1]).soil.soil_ph = 7.5
	# Test fixture injection only; production Presentation never gets live state.
	farming.set("_grid", fixture)
	before = infected.copy()
	_check(farming.transfer_crop(rice[0], rice[1]), "Mixed-state transplant succeeds")
	after = farming.get_grid_snapshot()
	_compare_payload(before, after.get_cell(rice[1]))
	_check(after.get_cell(rice[0]).soil.soil_ph == 6.0 and after.get_cell(rice[1]).soil.soil_ph == 7.5, "Soil stays at each location")
	_check(after.get_cell(rice[0]).validate().is_empty(), "Source reset is valid empty state")
	_check(farming.try_plant(rice[2], SimulationEnums.CropType.RICE), "Occupied destination fixture")
	_changes.clear()
	_check(not farming.transfer_crop(rice[1], rice[2]), "Occupied target rejected")
	_check(not farming.transfer_crop(rice[1], dry[0]), "Wrong terrain rejected")
	_check(not farming.transfer_crop(rice[1], rice[1]), "Same-cell move rejected")
	_check(not farming.transfer_crop(rice[1], Vector2i(-1, 0)), "Out-of-bounds destination rejected")
	_check(not farming.transfer_crop(Vector2i(-1, 0), rice[0]), "Out-of-bounds source rejected")
	_check(not farming.transfer_crop(rice[0], rice[3]), "Empty source rejected")
	_check(_changes.is_empty(), "Rejected moves emit no mutations")
	_compare_payload(before, farming.get_grid_snapshot().get_cell(rice[1]))
	_check(farming.remove_crop(rice[1]), "Infected crop removed")
	var removed: FieldCellState = farming.get_grid_snapshot().get_cell(rice[1])
	_check(not removed.has_crop and not removed.has_active_disease and removed.growth_elapsed_ticks == 0, "Removal clears growth and disease identity")
	_check(removed.validate().is_empty() and removed.infected_fraction == 0.0 and removed.exposed_fraction == 0.0 and removed.susceptible_fraction == 0.0 and removed.recovered_immune_fraction == 0.0 and removed.dead_fraction == 0.0, "Removal leaves zero compartment mass")
	_check(not farming.remove_crop(rice[1]), "Empty removal rejected")
	# Switching tools cancels a pending source selection.
	_click(scene.transfer_button.get_global_rect().get_center())
	await process_frame
	_click_cell(world, rice[2])
	await process_frame
	_click(scene.remove_button.get_global_rect().get_center())
	await process_frame
	_click(scene.transfer_button.get_global_rect().get_center())
	await process_frame
	_click_cell(world, rice[3])
	await process_frame
	_check(not farming.get_grid_snapshot().get_cell(rice[3]).has_crop, "Mode switch cancels pending transfer")
	scene.free()
	await process_frame
	_finish()


func _terrain_cells(grid: FieldGridState, terrain: SimulationEnums.TerrainType) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y: int in range(grid.height):
		for x: int in range(grid.width):
			if grid.get_cell(Vector2i(x, y)).terrain_type == terrain:
				result.append(Vector2i(x, y))
	return result


func _compare_payload(source: FieldCellState, target: FieldCellState) -> void:
	for property_name: StringName in PAYLOAD:
		_check(source.get(property_name) == target.get(property_name), "Preserved payload: " + String(property_name))


func _click_cell(world: FieldWorldView, coordinates: Vector2i) -> void:
	_click(world.terrain_layer.get_global_transform_with_canvas() * world.terrain_layer.map_to_local(coordinates))


func _click(position: Vector2) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event, true)
	var release: InputEventMouseButton = event.duplicate() as InputEventMouseButton
	release.pressed = false
	root.push_input(release, true)


func _capture(label: String) -> void:
	if OS.get_cmdline_user_args().has("--capture"):
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/field_tools_%s.png" % label)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	for message: String in _failures:
		print("FAIL: " + message)
	if _failures.is_empty():
		print("FIELD_MANAGEMENT_PASS")
	quit(0 if _failures.is_empty() else 1)

