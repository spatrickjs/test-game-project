extends SceneTree
const GameplayFixture = preload("res://tests/logic/gameplay_test_fixture.gd")
const QueueDriver = preload("res://tests/logic/queued_action_test_driver.gd")

class RejectedTurn:
	extends SimulationController
	func process_turn(_grid_state: FieldGridState, _diseases: DiseaseDatabase) -> bool:
		last_error = "Deliberate transaction rejection"
		return false

var _failures: PackedStringArray = PackedStringArray()
var _changes: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _cell() -> FieldCellState:
	var cell: FieldCellState = FieldCellState.new()
	cell.has_crop = true
	cell.soil = SoilState.new()
	cell.reset_crop_state()
	return cell

func _run() -> void:
	var crop: CropData = CropData.new()
	crop.display_name = "Lifecycle test"
	crop.growth_ticks = 4
	var normal: FieldCellState = _cell()
	var baseline: CropGrowthModel.Result = CropGrowthModel.evaluate(normal, crop)
	_check(baseline.errors.is_empty() and baseline.growth_elapsed_ticks == 1 and baseline.vitality == 1.0 and baseline.yield_quality_loss == 0.0, "Optimal baseline retains one tick and full quality")
	_check(normal.growth_elapsed_ticks == 0 and normal.vitality == 1.0, "Pure evaluation preserves input")
	for key: StringName in [&"nitrogen", &"potassium", &"soil_ph", &"moisture"]:
		var poor: FieldCellState = _cell()
		poor.soil.set(key, 0.0)
		var result: CropGrowthModel.Result = CropGrowthModel.evaluate(poor, crop)
		_check(result.errors.is_empty() and result.growth_credit < baseline.growth_credit and result.vitality < baseline.vitality and result.yield_quality_loss > 0.0, "Stress reduces growth/vitality/quality: " + key)
	for ph: float in [0.0, 14.0]:
		var poor: FieldCellState = _cell()
		poor.soil.soil_ph = ph
		_check(CropGrowthModel.evaluate(poor, crop).growth_credit == 0.0, "Extreme pH stalls growth")
	var wet: FieldCellState = _cell()
	wet.soil.moisture = 1.0
	_check(CropGrowthModel.evaluate(wet, crop).hydration < 0.001, "Over-saturation reduces hydration suitability")
	var partial: FieldCellState = _cell()
	partial.soil.nitrogen = 0.2
	var result: CropGrowthModel.Result = CropGrowthModel.evaluate(partial, crop)
	_check(is_equal_approx(result.growth_remainder, 0.5), "Half-rate growth accumulates fractional credit")
	partial.growth_remainder = 0.75
	result = CropGrowthModel.evaluate(partial, crop)
	_check(result.growth_elapsed_ticks == 1 and is_equal_approx(result.growth_remainder, 0.25), "Fractional credit converts to a whole tick")
	partial.vitality = 0.0
	_check(CropGrowthModel.evaluate(partial, crop).growth_credit == 0.0, "Zero vitality stalls growth")
	partial.vitality = 0.001
	partial.yield_quality_loss = 0.999
	result = CropGrowthModel.evaluate(partial, crop)
	_check(result.vitality == 0.0 and result.yield_quality_loss == 1.0, "Accumulated penalties stay bounded")
	partial.growth_elapsed_ticks = crop.growth_ticks
	result = CropGrowthModel.evaluate(partial, crop)
	_check(result.growth_elapsed_ticks == crop.growth_ticks and result.growth_remainder == 0.0, "Maturity cap discards unused fraction")
	_check(result.yield_quality_loss == 1.0, "Mature unharvested crop still suffers neglect")
	var neglected: FieldCellState = _cell()
	neglected.soil.potassium = 0.0
	for tick: int in range(25):
		var previous_vitality: float = neglected.vitality
		var previous_loss: float = neglected.yield_quality_loss
		var step: CropGrowthModel.Result = CropGrowthModel.evaluate(neglected, crop)
		_check(step.vitality <= previous_vitality and step.yield_quality_loss >= previous_loss, "Neglect accumulates monotonically")
		neglected.vitality = step.vitality
		neglected.yield_quality_loss = step.yield_quality_loss
	_check(neglected.vitality == 0.0 and neglected.yield_quality_loss > 0.5, "Repeated neglect causes lasting vitality and quality loss")
	var boundary: FieldCellState = _cell()
	boundary.soil.nitrogen = crop.growth_profile.nitrogen_minimum
	boundary.soil.potassium = crop.growth_profile.potassium_minimum
	boundary.soil.soil_ph = crop.growth_profile.ph_minimum
	boundary.soil.moisture = crop.growth_profile.moisture_maximum
	_check(CropGrowthModel.evaluate(boundary, crop).stress == 0.0, "Optimal boundaries are inclusive")
	var copied: CropData = crop.copy()
	copied.growth_profile.nitrogen_minimum = 0.9
	_check(crop.growth_profile.nitrogen_minimum == 0.4, "Profile copies are independent")
	copied.growth_profile.ph_falloff = NAN
	_check(not copied.validate().is_empty(), "Invalid profile rejected")
	normal.soil.moisture = NAN
	_check(not CropGrowthModel.evaluate(normal, crop).errors.is_empty() and is_nan(normal.soil.moisture), "Invalid soil rejected without repair")
	normal = _cell()
	normal.soil.nitrogen = 0.0
	copied = crop.copy()
	copied.growth_profile = null
	_check(CropGrowthModel.evaluate(normal, copied).growth_elapsed_ticks == 1, "Null profile preserves legacy growth")
	# Logic: transactional growth, transfer, harvesting, reset and rollback.
	var farming: FarmingController = FarmingController.new()
	farming.crop_database = CropDatabase.new()
	farming.crop_database.crops.append(crop)
	farming.terrain_database = load("res://src/data/databases/terrain_database.tres") as TerrainDatabase
	farming.initial_soil = SoilState.new()
	farming.initial_abiotic = AbioticState.new()
	farming.field_size = Vector2i(3, 1)
	farming.terrain_bands = [SimulationEnums.TerrainType.DRY_SOIL]
	_check(farming.initialize_field(), "Initialize lifecycle fixture")
	_check(farming.try_plant(Vector2i.ZERO, crop.crop_type), "Plant lifecycle fixture")
	_check(not farming.harvest_crop(Vector2i.ZERO).success, "Immature harvest rejected")
	_check(not farming.harvest_crop(Vector2i(-1, 0)).success, "Out-of-bounds harvest rejected")
	var live: FieldGridState = farming.get("_grid") as FieldGridState
	live.get_cell(Vector2i.ZERO).soil.nitrogen = 0.2
	_check(farming.advance_growth(), "Stressed growth turn")
	var stressed: FieldCellState = farming.get_grid_snapshot().get_cell(Vector2i.ZERO)
	_check(stressed.vitality < 1.0 and stressed.growth_remainder > 0.0 and stressed.growth_elapsed_ticks == 0, "Logic commits stress and fractional growth")
	_check(farming.transfer_crop(Vector2i.ZERO, Vector2i(1, 0)), "Move stressed plant")
	var moved: FieldCellState = farming.get_grid_snapshot().get_cell(Vector2i(1, 0))
	_check(moved.vitality == stressed.vitality and moved.growth_remainder == stressed.growth_remainder and moved.yield_quality_loss == stressed.yield_quality_loss, "Transfer preserves full lifecycle payload")
	_check(moved.soil.nitrogen == 0.5, "Transfer retains destination soil")
	var before: FieldCellState = moved.copy()
	_check(not farming.advance_simulated_turn(RejectedTurn.new(), DiseaseDatabase.new()), "Late turn failure rolls back")
	moved = farming.get_grid_snapshot().get_cell(Vector2i(1, 0))
	_check(moved.vitality == before.vitality and moved.growth_remainder == before.growth_remainder and moved.growth_elapsed_ticks == before.growth_elapsed_ticks and moved.yield_quality_loss == before.yield_quality_loss, "All lifecycle fields roll back")
	_check(farming.try_plant(Vector2i.ZERO, crop.crop_type), "Replant cleared source")
	live = farming.get("_grid") as FieldGridState
	live.get_cell(Vector2i(1, 0)).growth_elapsed_ticks = 99
	_check(not farming.advance_growth(), "Later invalid crop rejects batch")
	_check(farming.get_grid_snapshot().get_cell(Vector2i.ZERO).growth_elapsed_ticks == 0 and farming.get_grid_snapshot().get_cell(Vector2i.ZERO).vitality == 1.0, "Earlier staged growth is not partially committed")
	live.get_cell(Vector2i(1, 0)).growth_elapsed_ticks = before.growth_elapsed_ticks
	for turn: int in range(6):
		_check(farming.advance_growth(), "Growth to maturity")
	farming.cell_changed.connect(func(_coordinates: Vector2i) -> void: _changes += 1)
	var receipt: HarvestResult = farming.harvest_crop(Vector2i(1, 0))
	_check(receipt.success and receipt.quality_multiplier < 1.0 and receipt.quality_multiplier > 0.0, "Stressed harvest has reduced quality")
	_check(_changes == 1 and not farming.get_grid_snapshot().get_cell(Vector2i(1, 0)).has_crop, "Harvest commits once then signals")
	_check(not farming.harvest_crop(Vector2i(1, 0)).success and _changes == 1, "No duplicate harvest")
	_check(farming.try_plant(Vector2i(1, 0), crop.crop_type), "Replant harvested tile")
	moved = farming.get_grid_snapshot().get_cell(Vector2i(1, 0))
	_check(moved.vitality == 1.0 and moved.yield_quality_loss == 0.0 and moved.growth_remainder == 0.0, "Replant resets all lifecycle state")
	farming.free()
	# Saved scene and native HUD/tile input exercise harvest wiring.
	root.size = Vector2i(1280, 720)
	var packed: PackedScene = load("res://field_prototype.tscn") as PackedScene
	var scene: FieldPrototypePresenter = packed.instantiate() as FieldPrototypePresenter
	GameplayFixture.prepare(scene)
	root.add_child(scene)
	GameplayFixture.start(scene)
	for frame: int in range(5):
		await process_frame
	_check(scene.harvest_button != null and scene.harvest_button.owner == scene, "Harvest control saved and wired")
	var cell_pos: Vector2i = Vector2i(-1, -1)
	var scene_grid: FieldGridState = scene.farming_controller.get_grid_snapshot()
	for y: int in range(scene_grid.height):
		for x: int in range(scene_grid.width):
			var coordinate: Vector2i = Vector2i(x, y)
			if cell_pos.x < 0 and scene_grid.get_cell(coordinate).terrain_type == SimulationEnums.TerrainType.PADDY_MUD:
				cell_pos = coordinate
	_check(scene.farming_controller.try_plant(cell_pos, SimulationEnums.CropType.RICE), "Plant saved scene crop")
	for turn: int in range(4):
		_check(scene.turn_controller.advance_turn(), "Advance saved scene")
	_click(scene.harvest_button.get_global_rect().get_center())
	var point: Vector2 = scene.world_view.terrain_layer.get_global_transform_with_canvas() * scene.world_view.terrain_layer.map_to_local(cell_pos)
	_click(point)
	_check(scene.farming_controller.get_grid_snapshot().get_cell(cell_pos).has_crop, "Harvest waits for the farmer")
	_check(QueueDriver.finish(scene), "Harvest queue completes")
	_check(not scene.farming_controller.get_grid_snapshot().get_cell(cell_pos).has_crop, "Native harvest click clears mature crop")
	_check(scene.status_label.text.contains("100%") and scene.turn_controller.turn_index == 4, "Harvest reports quality without advancing time")
	scene.queue_free()
	await process_frame
	if _failures.is_empty():
		print("CROP_GROWTH_PASS")
		quit(0)
	else:
		for failure: String in _failures:
			printerr("FAIL: " + failure)
		quit(1)

func _click(screen_pos: Vector2) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = screen_pos
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate() as InputEventMouseButton
	event.pressed = false
	root.push_input(event, true)

func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)
