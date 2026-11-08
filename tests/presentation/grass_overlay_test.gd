extends SceneTree

var _failures: PackedStringArray = PackedStringArray()

func _initialize() -> void:
	var view: FieldWorldView = FieldWorldView.new()
	var grid: FieldGridState = FieldGridState.new()
	_check(grid.initialize(4, 4, AbioticState.new()), "Initialize typed grid")
	grid.get_cell(Vector2i.ZERO).terrain_type = SimulationEnums.TerrainType.DRY_SOIL
	grid.get_cell(Vector2i.ZERO).soil = SoilState.new()
	view._render_grass_overlay(grid)
	var overlay: TileMapLayer = TileMapLayer.new()
	view.add_child(overlay)
	view.grass_overlay_layer = overlay
	var texture_image: Image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	texture_image.fill(Color.WHITE)
	var atlas: TileSetAtlasSource = TileSetAtlasSource.new()
	atlas.texture = ImageTexture.create_from_image(texture_image)
	atlas.texture_region_size = Vector2i(16, 16)
	atlas.create_tile(Vector2i.ZERO)
	overlay.tile_set = TileSet.new()
	overlay.tile_set.add_source(atlas, 1)
	view.tuft_spawn_chance = 1.0
	view._render_grass_overlay(grid)
	_check(overlay.get_used_cells().size() == 15, "Decorates every grass cell at 100 percent")
	_check(overlay.get_cell_source_id(Vector2i.ZERO) == -1, "Non-grass cells excluded")
	_check(grid.get_cell(Vector2i.ZERO).soil.moisture == 0.5, "Soil unchanged")
	view.tuft_spawn_chance = 0.5
	view._render_grass_overlay(grid)
	var first_cells: Array[Vector2i] = overlay.get_used_cells()
	view._render_grass_overlay(grid)
	_check(first_cells == overlay.get_used_cells(), "Repeated rendering preserves decorations")
	var converted: Vector2i = Vector2i(1, 0)
	grid.get_cell(converted).terrain_type = SimulationEnums.TerrainType.DRY_SOIL
	grid.get_cell(converted).soil = SoilState.new()
	view._render_grass_overlay(grid)
	first_cells.erase(converted)
	_check(first_cells == overlay.get_used_cells(), "Conversion removes only its tuft without relocating others")
	view.tuft_spawn_chance = 0.0
	view._render_grass_overlay(grid)
	_check(overlay.get_used_cells().is_empty(), "Zero chance clears old decorations")
	view.animated_grass_source_id = 99
	view._render_grass_overlay(grid)
	_check(overlay.get_used_cells().is_empty(), "Missing optional source is safe")
	view.animated_grass_source_id = 1
	view.grass_tuft_atlas_coords = Vector2i(99, 99)
	view._render_grass_overlay(grid)
	_check(overlay.get_used_cells().is_empty(), "Missing optional tile is safe")
	overlay.set_cell(Vector2i.ZERO, 1, Vector2i.ZERO)
	view.terrain_layer = overlay
	view._render_grass_overlay(grid)
	_check(overlay.get_used_cells().size() == 1, "Misassigned overlay never clears base terrain")
	view.free()
	if _failures.is_empty():
		print("GRASS_OVERLAY_PASS")
		quit(0)
	else:
		for failure: String in _failures:
			printerr("FAIL: " + failure)
		quit(1)

func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)
