extends SceneTree
## Headless behavioral smoke check; creates no scenes or resource files.

var _failures: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	var farming: FarmingController = FarmingController.new()
	farming.crop_database = CropDatabase.new()
	farming.terrain_database = TerrainDatabase.new()
	farming.initial_soil = SoilState.new()
	farming.initial_abiotic = AbioticState.new()
	var crop_types: Array[SimulationEnums.CropType] = [
		SimulationEnums.CropType.SUGARCANE, SimulationEnums.CropType.RICE, SimulationEnums.CropType.CORN,
	]
	for crop_type: SimulationEnums.CropType in crop_types:
		var crop: CropData = CropData.new()
		crop.crop_type = crop_type
		crop.display_name = "Test crop %d" % crop_type
		crop.growth_ticks = 3
		farming.crop_database.crops.append(crop)
	var terrain_types: Array[SimulationEnums.TerrainType] = [
		SimulationEnums.TerrainType.DRY_SOIL, SimulationEnums.TerrainType.PADDY_MUD, SimulationEnums.TerrainType.GRASS,
	]
	for terrain_type: SimulationEnums.TerrainType in terrain_types:
		var terrain: TerrainData = TerrainData.new()
		terrain.terrain_type = terrain_type
		terrain.display_name = "Test terrain %d" % terrain_type
		terrain.is_plantable = terrain_type != SimulationEnums.TerrainType.GRASS
		if terrain_type == SimulationEnums.TerrainType.DRY_SOIL:
			terrain.allowed_crops.assign([SimulationEnums.CropType.SUGARCANE, SimulationEnums.CropType.CORN])
		elif terrain_type == SimulationEnums.TerrainType.PADDY_MUD:
			terrain.allowed_crops.assign([SimulationEnums.CropType.RICE])
		farming.terrain_database.terrains.append(terrain)
	_check(farming.initialize_field(), "Field initialization: " + farming.last_error)
	if not farming.is_initialized():
		farming.free()
		_finish()
		return
	var snapshot: FieldGridState = farming.get_grid_snapshot()
	_check(snapshot.width == 9 and snapshot.height == 6, "Default dimensions")
	for y: int in range(6):
		for x: int in range(9):
			var expected: SimulationEnums.TerrainType = terrain_types[floori(float(x) / 3.0)]
			_check(snapshot.get_cell(Vector2i(x, y)).terrain_type == expected, "Terrain strip")
	_check(snapshot.get_cell(Vector2i(6, 0)).soil == null, "Grass has no soil")
	snapshot.get_cell(Vector2i.ZERO).soil.nitrogen = 0.0
	_check(farming.get_grid_snapshot().get_cell(Vector2i.ZERO).soil.nitrogen == 0.5, "Snapshot isolation")
	_check(farming.try_plant(Vector2i(0, 0), SimulationEnums.CropType.SUGARCANE), "Sugarcane on dry soil")
	_check(farming.try_plant(Vector2i(1, 0), SimulationEnums.CropType.CORN), "Corn on dry soil")
	_check(farming.try_plant(Vector2i(3, 0), SimulationEnums.CropType.RICE), "Rice on paddy mud")
	_check(not farming.try_plant(Vector2i(2, 0), SimulationEnums.CropType.RICE), "Reject rice on dry soil")
	_check(not farming.try_plant(Vector2i(4, 0), SimulationEnums.CropType.CORN), "Reject corn on mud")
	_check(not farming.try_plant(Vector2i(6, 0), SimulationEnums.CropType.CORN), "Reject grass")
	_check(not farming.try_plant(Vector2i.ZERO, SimulationEnums.CropType.SUGARCANE), "Reject occupied tile")
	_check(not farming.try_plant(Vector2i(-1, 0), SimulationEnums.CropType.CORN), "Reject out-of-bounds")
	var turns: TurnController = TurnController.new()
	turns.farming_controller = farming
	_check(turns.advance_turn(), "First turn")
	_check(farming.get_grid_snapshot().get_cell(Vector2i.ZERO).growth_elapsed_ticks == 1, "One tick per turn")
	for tick: int in range(5):
		_check(turns.advance_turn(), "Additional turn %d" % tick)
	snapshot = farming.get_grid_snapshot()
	_check(turns.turn_index == 6, "Turn count")
	_check(snapshot.get_cell(Vector2i.ZERO).growth_elapsed_ticks == 3, "Growth cap")
	_check(snapshot.get_cell(Vector2i.ZERO).is_mature(farming.crop_database.get_crop(SimulationEnums.CropType.SUGARCANE)), "Derived maturity")
	_check(snapshot.validate().is_empty(), "Runtime state remains valid")
	var invalid_map: TerrainTileVisualMap = TerrainTileVisualMap.new()
	_check(not invalid_map.validate(null).is_empty(), "Missing TileSet validation")
	turns.free()
	farming.free()
	_finish()


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)


func _finish() -> void:
	if _failures.is_empty():
		print("FIELD_PROTOTYPE_SMOKE_PASS")
		quit(0)
	else:
		for failure: String in _failures:
			printerr("FAIL: " + failure)
		quit(1)
