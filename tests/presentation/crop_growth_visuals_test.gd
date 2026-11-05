extends SceneTree
## Saved-scene integration, exact boundaries, independent copies and clearing.

var _failures: PackedStringArray = PackedStringArray()
const Normalizer: Script = preload("res://tools/crop_texture_normalizer.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# Padding and off-center artwork must not change normalized pixels.
	var small: Image = Image.create(40, 80, false, Image.FORMAT_RGBA8)
	small.fill(Color.TRANSPARENT)
	small.fill_rect(Rect2i(4, 9, 20, 60), Color.GREEN)
	var padded: Image = Image.create(160, 160, false, Image.FORMAT_RGBA8)
	padded.fill(Color.TRANSPARENT)
	padded.blit_rect(small, Rect2i(0, 0, 40, 80), Vector2i(93, 21))
	padded.set_pixel(10, 159, Color.GREEN)
	padded.set_pixel(150, 150, Color(0.0, 1.0, 0.0, 0.01))
	for stage: int in range(4):
		var first: Image = Normalizer.normalize(small, Vector2i(276, 140), stage)
		var second: Image = Normalizer.normalize(padded, Vector2i(276, 140), stage)
		_check(first.get_data() == second.get_data(), "Padding-independent normalization stage %d" % stage)
	var empty: Image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	empty.fill(Color.TRANSPARENT)
	_check(Normalizer.normalize(empty, Vector2i(276, 140), 0) == null, "Empty artwork rejected")
	var narrow: Image = Image.create(120, 120, false, Image.FORMAT_RGBA8)
	narrow.fill(Color.TRANSPARENT)
	narrow.fill_rect(Rect2i(45, 10, 20, 100), Color.GREEN)
	var wide: Image = narrow.duplicate() as Image
	wide.fill_rect(Rect2i(5, 10, 110, 60), Color.GREEN)
	var seed_frames: Array[Image] = [narrow, wide]
	var mature_frames: Array[Image] = [narrow, narrow]
	var all_stages: Array = [seed_frames, mature_frames, mature_frames, mature_frames]
	var shared: float = Normalizer.shared_strip_mature_height(all_stages, Vector2i(276, 140))
	_check(shared < 250.0, "Shared budget includes wider later animation frames")
	var seed_strip: Image = Normalizer.normalize_prepared_strip(seed_frames, Vector2i(276, 140), 0, shared, 0.5)
	var mature_strip: Image = Normalizer.normalize_prepared_strip(mature_frames, Vector2i(276, 140), 3, shared)
	_check(absf(float(seed_strip.get_used_rect().size.y) / float(mature_strip.get_used_rect().size.y) - 0.175) < 0.02, "Animation-wide budget preserves seedling ratio")
	var different_canvas: Array[Image] = [narrow, small]
	_check(Normalizer.normalize_prepared_strip(different_canvas, Vector2i(276, 140), 0) == null, "Mismatched frame canvases rejected")
	var ticks: Array[int] = [-1, 0, 2, 3, 5, 6, 8, 9, 10]
	var stages: Array[int] = [0, 0, 0, 1, 1, 2, 2, 3, 3]
	for index: int in range(ticks.size()):
		_check(FieldWorldView.get_growth_stage(ticks[index], 9) == stages[index], "Exact third boundary %d" % ticks[index])
	_check(FieldWorldView.get_growth_stage(0, 1) == 0, "One-tick seedling")
	_check(FieldWorldView.get_growth_stage(1, 1) == 3, "One-tick mature")
	_check(FieldWorldView.get_growth_stage(1, 0) == 0, "Invalid duration safe fallback")
	var packed: PackedScene = load("res://field_prototype.tscn") as PackedScene
	var presenter: FieldPrototypePresenter = packed.instantiate() as FieldPrototypePresenter
	root.add_child(presenter)
	await process_frame
	var farming: FarmingController = presenter.farming_controller
	var world: FieldWorldView = presenter.world_view
	_check(world.crop_layer != null, "Persistent crop layer wired")
	if world.crop_layer == null:
		presenter.free()
		_finish()
		return
	_check(world.validate_crop_visuals(farming.crop_database).is_empty(), "All twelve saved atlas mappings valid")
	_check(world.crop_layer.tile_set.get_source_count() == 12, "Exactly twelve separate sources")
	_check(world.crop_layer.owner == presenter, "Crop layer ownership serialized")
	_check(not world.crop_overlay.visible, "Debug markers hidden")
	for crop: CropData in farming.crop_database.crops:
		var mature_atlas: TileSetAtlasSource = world.crop_layer.tile_set.get_source(crop.growth_stage_source_ids[3]) as TileSetAtlasSource
		var mature_height: int = _animation_bounds(mature_atlas).size.y
		var previous_height: int = 0
		for stage: int in range(4):
			var atlas: TileSetAtlasSource = world.crop_layer.tile_set.get_source(crop.growth_stage_source_ids[stage]) as TileSetAtlasSource
			var pixels: Image = atlas.texture.get_image()
			var frame_count: int = atlas.get_tile_animation_frames_count(Vector2i.ZERO)
			var frame_size: Vector2i = atlas.texture_region_size
			_check(frame_size == Vector2i(270, 400), "Consistent per-frame canvas")
			_check(frame_count == 11 and atlas.get_tile_animation_columns(Vector2i.ZERO) == 11, "Saved eleven-frame animation configured")
			_check(is_equal_approx(atlas.get_tile_animation_speed(Vector2i.ZERO), 8.0), "Saved animation speed")
			_check(pixels.get_size() == Vector2i(frame_size.x * frame_count, frame_size.y), "Strip dimensions match frame count")
			var bounds: Rect2i = _animation_bounds(atlas)
			var reference_root: Rect2i = Rect2i()
			for frame: int in range(frame_count):
				var region: Rect2i = atlas.get_tile_texture_region(Vector2i.ZERO, frame)
				_check(region == Rect2i(frame * frame_size.x, 0, frame_size.x, frame_size.y), "Animation frames address separate cells")
				var single: Image = pixels.get_region(region)
				var used: Rect2i = single.get_used_rect()
				_check(used.has_area() and used.size.x <= 262 and used.size.y <= 392, "Each frame fits tile-relative limits")
				_check(used.size.y >= 50, "Readable animated crop height")
				var origin: Vector2i = atlas.get_tile_data(Vector2i.ZERO, 0).texture_origin
				_check(used.end.y - frame_size.y / 2.0 - origin.y == 0.0, "%s stage %d frame %d root height" % [crop.display_name, stage, frame])
				# A wind-swaying crown may move horizontally; the soil anchor must
				# remain inside the actual stem base, not the entire canopy box.
				var base: Rect2i = single.get_region(Rect2i(0, used.end.y - 4, frame_size.x, 4)).get_used_rect()
				var anchor_x: int = int(frame_size.x / 2.0) + origin.x
				_check(anchor_x >= base.position.x and anchor_x < base.end.x, "%s stage %d frame %d stem anchored" % [crop.display_name, stage, frame])
				_check(is_equal_approx(atlas.get_tile_animation_frame_duration(Vector2i.ZERO, frame), 1.0), "Uniform frame duration")
				if frame == 0:
					reference_root = base
				else:
					_check(base.intersects(reference_root), "Root footprint remains stable through animation")
			_check(bounds.size.x <= 262 and bounds.size.y <= 392, "Animation union fits tile envelope")
			_check(bounds.size.y > previous_height, "%s stage heights strictly increase" % crop.display_name)
			previous_height = bounds.size.y
			var expected_ratios: Array[float] = [0.35, 0.60, 0.85, 1.0]
			if crop.crop_type in [SimulationEnums.CropType.CORN, SimulationEnums.CropType.SUGARCANE]:
				expected_ratios[0] = 0.175
			_check(absf(float(bounds.size.y) / float(mature_height) - expected_ratios[stage]) < 0.02, "%s stage %d relative height" % [crop.display_name, stage])
			if stage == 0:
				_check(float(bounds.size.y) <= float(mature_height) * 0.4, "%s seedling at most 40 percent of mature height" % crop.display_name)
			print("CROP_SCALE %s stage %d: %d px" % [crop.display_name, stage, bounds.size.y])
	var snapshot: FieldGridState = farming.get_grid_snapshot()
	var coordinates: Array[Vector2i] = []
	for crop: CropData in farming.crop_database.crops:
		var position: Vector2i = Vector2i(-1, -1)
		for y: int in range(snapshot.height):
			for x: int in range(snapshot.width):
				var candidate: Vector2i = Vector2i(x, y)
				if position.x < 0 and not coordinates.has(candidate) and FieldGridQueries.can_plant(snapshot, candidate, crop.crop_type, farming.crop_database, farming.terrain_database):
					position = candidate
		_check(position.x >= 0, "Eligible cell found")
		coordinates.append(position)
		_check(farming.try_plant(position, crop.crop_type), "Planting succeeds")
		_check(world.crop_layer.get_cell_source_id(position) == crop.growth_stage_source_ids[0], "Plant signal renders seedling")
	await _capture("seedlings")
	# Existing next-turn intent invokes Logic and returns a detached snapshot.
	for tick: int in range(1, 7):
		presenter.next_turn_button.pressed.emit()
		for index: int in range(coordinates.size()):
			var crop: CropData = farming.crop_database.crops[index]
			var expected: int = FieldWorldView.get_growth_stage(tick, crop.growth_ticks)
			_check(world.crop_layer.get_cell_source_id(coordinates[index]) == crop.growth_stage_source_ids[expected], "Turn %d renders %s stage %d" % [tick, crop.display_name, expected])
			_check(world.crop_layer.get_cell_atlas_coords(coordinates[index]) == crop.growth_stage_atlas_coords[expected], "Atlas coordinates match")
		if tick <= 5:
			await _capture("turn_%d" % tick)
	# Presentation can render snapshots without changing authoritative growth.
	var source: CropData = farming.crop_database.crops[0]
	var copied: CropData = source.copy()
	copied.growth_stage_source_ids[0] = 99999
	copied.growth_stage_atlas_coords[0] = Vector2i(99, 99)
	_check(source.growth_stage_source_ids[0] != 99999 and source.growth_stage_atlas_coords[0] != Vector2i(99, 99), "Visual arrays copied independently")
	var bad_catalog: CropDatabase = CropDatabase.new()
	bad_catalog.crops.append(copied)
	_check(not world.validate_crop_visuals(bad_catalog).is_empty(), "Unknown source rejected")
	copied.growth_stage_source_ids = source.growth_stage_source_ids.duplicate()
	_check(not world.validate_crop_visuals(bad_catalog).is_empty(), "Missing atlas coordinate rejected")
	copied.growth_stage_source_ids = [0]
	_check(not world.validate_crop_visuals(bad_catalog).is_empty(), "Wrong array length rejected")
	_check(farming.clear_crop(coordinates[0]), "Crop clears")
	_check(world.crop_layer.get_cell_source_id(coordinates[0]) == -1, "Clear signal erases stale tile")
	presenter.free()
	await process_frame
	_finish()


func _capture(label: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture"):
		return
	await process_frame
	await RenderingServer.frame_post_draw
	var screenshot: Image = root.get_texture().get_image()
	_check(screenshot.save_png("res://.godot/crop_visual_%s.png" % label) == OK, "Screenshot saved")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	for message: String in _failures:
		print("FAIL: " + message)
	if _failures.is_empty():
		print("CROP_GROWTH_VISUALS_PASS")
	quit(0 if _failures.is_empty() else 1)


func _animation_bounds(atlas: TileSetAtlasSource) -> Rect2i:
	var pixels: Image = atlas.texture.get_image()
	var result: Rect2i = Rect2i()
	for frame: int in range(atlas.get_tile_animation_frames_count(Vector2i.ZERO)):
		var region: Rect2i = atlas.get_tile_texture_region(Vector2i.ZERO, frame)
		var bounds: Rect2i = pixels.get_region(region).get_used_rect()
		result = result.merge(bounds) if result.has_area() else bounds
	return result
