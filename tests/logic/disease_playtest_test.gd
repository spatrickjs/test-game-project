extends SceneTree
const GameplayFixture = preload("res://tests/logic/gameplay_test_fixture.gd")

var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed: PackedScene = load("res://field_prototype.tscn") as PackedScene
	check(ResourceLoader.get_resource_uid("res://field_prototype.tscn") == ResourceUID.text_to_id(str(ProjectSettings.get_setting("application/run/main_scene"))), "Main scene UID preserved")
	for algorithm: int in [-1, 1, 2]:
		var presenter: FieldPrototypePresenter = packed.instantiate() as FieldPrototypePresenter
		var panel: TileInspectorView = presenter.tile_inspector
		panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		panel.position = Vector2(750.0, 12.0)
		panel.size = Vector2(340.0, 560.0)
		GameplayFixture.prepare(presenter, true)
		root.add_child(presenter)
		GameplayFixture.start(presenter)
		for frame: int in range(4):
			await process_frame
		var farming: FarmingController = presenter.farming_controller
		var turns: TurnController = presenter.turn_controller
		check(turns.disease_database.resource_path == "res://src/data/databases/default_disease_database.tres", "Saved catalog wired")
		check(panel.disease_database == turns.disease_database, "Inspector shares disease catalog")
		check(turns.disease_database.validate().is_empty(), "Saved disease valid")
		check(panel.seed_infection_button.owner == presenter and presenter.algorithm_selector.owner == presenter, "New UI serialized with ownership")
		check(presenter.algorithm_selector.item_count == 4, "Four baked algorithm options")
		presenter.algorithm_selector.select(algorithm + 1)
		presenter.algorithm_selector.item_selected.emit(algorithm + 1)
		check(turns.simulation_controller.algorithm_override == algorithm, "Algorithm selected before seeding")
		var seed_position: Vector2i = Vector2i(-1, -1)
		var neighbor_position: Vector2i = Vector2i(-1, -1)
		var dry_position: Vector2i = Vector2i(-1, -1)
		var snapshot: FieldGridState = farming.get_grid_snapshot()
		for x: int in range(snapshot.width):
			if snapshot.get_cell(Vector2i(x, 0)).terrain_type == SimulationEnums.TerrainType.PADDY_MUD:
				seed_position = Vector2i(x, 0)
				neighbor_position = Vector2i(x, 1)
			if snapshot.get_cell(Vector2i(x, 0)).terrain_type == SimulationEnums.TerrainType.DRY_SOIL:
				dry_position = Vector2i(x, 0)
		check(farming.try_plant(seed_position, SimulationEnums.CropType.RICE), "Plant rice host")
		check(farming.try_plant(neighbor_position, SimulationEnums.CropType.RICE), "Plant neighboring rice")
		check(farming.try_plant(dry_position, SimulationEnums.CropType.CORN), "Plant nonhost")
		check(not farming.seed_infection(dry_position, SimulationEnums.DiseaseId.RICE_BLAST, turns.disease_database, turns.simulation_controller), "Reject corn host")
		check(not farming.seed_infection(Vector2i(-1, 0), SimulationEnums.DiseaseId.RICE_BLAST, turns.disease_database, turns.simulation_controller), "Reject invalid coordinate")
		presenter.world_view.cell_clicked.emit(seed_position)
		for frame: int in range(3):
			await process_frame
		check(not panel.seed_infection_button.disabled, "Clean rice enables seed action")
		var intents: Array[int] = [0]
		panel.seed_infection_requested.connect(func() -> void: intents[0] += 1)
		_click(panel.seed_infection_button)
		await process_frame
		check(intents[0] == 1, "Native button click emits one seed intent")
		var seeded: FieldCellState = farming.get_grid_snapshot().get_cell(seed_position)
		check(seeded.has_active_disease and seeded.active_disease_id == SimulationEnums.DiseaseId.RICE_BLAST, "Patient zero assigned disease")
		check(seeded.infected_fraction == (1.0 if algorithm == 2 else 0.2), "Algorithm-appropriate infection")
		check(seeded.growth_elapsed_ticks == 0 and turns.turn_index == 0, "Seed does not advance growth/turn")
		check(panel.seed_infection_button.disabled and panel.disease_label.text.contains("Rice Blast"), "Inspector refreshes and disables repeat seed")
		check(not farming.seed_infection(seed_position, SimulationEnums.DiseaseId.RICE_BLAST, turns.disease_database, turns.simulation_controller), "Repeat seed rejected")
		if algorithm != 2:
			presenter.algorithm_selector.select(3)
			presenter.algorithm_selector.item_selected.emit(3)
			check(turns.simulation_controller.algorithm_override == algorithm and presenter.algorithm_selector.selected == algorithm + 1, "Incompatible CA selection rolls back UI and model")
		turns.simulation_controller.rng.seed = 42
		presenter.next_turn_button.pressed.emit()
		await process_frame
		var neighbor: FieldCellState = farming.get_grid_snapshot().get_cell(neighbor_position)
		check(turns.turn_index == 1 and neighbor.validate().is_empty(), "Next Turn succeeds")
		if algorithm != 2:
			check(neighbor.exposed_fraction > 0.0 if algorithm == 1 else neighbor.infected_fraction > 0.0, "Disease spreads to neighboring rice")
		else:
			check(CompartmentMath.one_hot_index(neighbor) >= 0, "CA stays one-hot")
		check(not farming.get_grid_snapshot().get_cell(dry_position).has_active_disease, "Disease excludes incompatible crops")
		presenter.queue_free()
		await process_frame
	if failures == 0:
		print("DISEASE_PLAYTEST_PASS")
	quit(0 if failures == 0 else 1)


func _click(button: Button) -> void:
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.position = button.get_global_transform_with_canvas() * (button.size * 0.5)
	press.global_position = press.position
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	root.push_input(press, true)
	var release: InputEventMouseButton = press.duplicate() as InputEventMouseButton
	release.pressed = false
	root.push_input(release, true)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)
