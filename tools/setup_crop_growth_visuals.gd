@tool
extends EditorScript
## Run in the editor via File -> Run (Ctrl+Shift+X).
## Synchronous execution prevents EditorScript RefCounted premature freed bug.

const SCENE_PATH: String = "res://field_prototype.tscn"
const Normalizer: Script = preload("res://tools/crop_texture_normalizer.gd")
const GENERATED_DIR: String = "res://assets/art/tilesets/crops/normalized"
const CROP_NAMES: Array[String] = ["rice", "corn", "sugarcane"]
const FRAME_COUNT: int = 11
## Enable to import the diseased folders instead of healthy crops.
const IMPORT_DISEASES: bool = true
const DISEASE_FOLDERS: Dictionary = {
	"rice": {"rice_tungro": 3, "bacterial_leaf_blight": 4, "rice_blast": 5},
	"corn": {"common_corn_rust": 6, "philippine_downy_mildew": 7, "ear_rot": 8},
	"sugarcane": {"red_striped_soft_scale_insect": 0, "sugarcane_smut": 1, "leaf_scald": 2},
}
const ANIMATION_FPS: float = 8.0


func _run() -> void:
	run_setup()


func run_setup() -> int:
	print("--- Starting Crop Animation & Visual Setup ---")
	var filesystem: EditorFileSystem = EditorInterface.get_resource_filesystem()
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GENERATED_DIR)) != OK:
		return _fail("Could not create normalized texture directory.")

	var scene: Node = EditorInterface.get_edited_scene_root()
	if scene == null or scene.scene_file_path != SCENE_PATH:
		EditorInterface.open_scene_from_path(SCENE_PATH)
		scene = EditorInterface.get_edited_scene_root()
	if scene == null or scene.scene_file_path != SCENE_PATH:
		return _fail("Please open res://field_prototype.tscn in the editor first, then press File -> Run.")

	var world: Node = scene.get("world_view") as Node
	if world == null:
		world = scene.get_node_or_null("World")
	if world == null:
		return _fail("Could not find World / world_view node in scene.")

	var terrain: TileMapLayer = world.get("terrain_layer") as TileMapLayer
	if terrain == null:
		terrain = world.get_node_or_null("Terrain") as TileMapLayer
	if terrain == null or terrain.tile_set == null:
		return _fail("Terrain layer and TileSet are required.")

	var existing: Node = world.get_node_or_null("Crops")
	if existing != null and (not existing is TileMapLayer or not existing.has_meta("crop_growth_setup")):
		return _fail("World/Crops already exists and is not owned by this setup; left unchanged.")

	var layer: TileMapLayer = existing as TileMapLayer
	var is_new: bool = layer == null
	if is_new:
		layer = TileMapLayer.new()
		layer.name = "Crops"
		world.add_child(layer)
		layer.owner = scene
		layer.set_meta("crop_growth_setup", true)
		layer.transform = terrain.transform
		layer.z_index = terrain.z_index + 1
		layer.y_sort_enabled = true

	var tiles: TileSet = layer.tile_set
	if tiles == null:
		tiles = TileSet.new()
		tiles.tile_shape = terrain.tile_set.tile_shape
		tiles.tile_layout = terrain.tile_set.tile_layout
		tiles.tile_offset_axis = terrain.tile_set.tile_offset_axis
		tiles.tile_size = terrain.tile_set.tile_size
		layer.tile_set = tiles

	var cell_size: Vector2i = Normalizer.single_cell_size(tiles.tile_size)

	var jobs: Array[Dictionary] = []
	for crop_name: String in CROP_NAMES:
		if IMPORT_DISEASES:
			for disease: String in DISEASE_FOLDERS[crop_name]:
				jobs.append({"crop": crop_name, "disease": disease})
		else:
			jobs.append({"crop": crop_name, "disease": ""})
	for job: Dictionary in jobs:
		var crop_name: String = job.crop
		var disease: String = job.disease
		var crop_path: String = "res://src/data/resources/%s_data.tres" % crop_name
		var crop: Resource = load(crop_path)
		if crop == null:
			return _fail("Missing crop resource: " + crop_path)
		var ids: Array[int] = []
		var coords: Array[Vector2i] = []
		var stage_frame_sets: Array = []

		for stage: int in range(4):
			var frames: Array[Image] = _load_disease_frames(crop_name, disease, stage) if IMPORT_DISEASES else _load_stage_frames(crop_name, stage)
			if frames.is_empty():
				return _fail("Could not load frames or static PNG for %s stage %d" % [crop_name, stage])
			print("Loaded %d frame(s) for %s stage %d" % [frames.size(), crop_name, stage])
			stage_frame_sets.append(frames)

		var shared_height: float = Normalizer.shared_strip_mature_height(stage_frame_sets, tiles.tile_size)
		if shared_height <= 0.0:
			return _fail("Invalid crop stage images: " + crop_name)

		for stage: int in range(4):
			var source_name: String = "%s_stage_%d" % [crop_name, stage]
			if IMPORT_DISEASES:
				source_name = "%s_%s_stage_%d" % [crop_name, disease, stage]
			var source_id: int = _find_source(tiles, source_name)
			var artwork_scale: float = 0.5 if stage == 0 and crop_name in ["corn", "sugarcane"] else 1.0
			var frames: Array[Image] = stage_frame_sets[stage]
			var normalized: Image = Normalizer.normalize_prepared_strip(frames, tiles.tile_size, stage, shared_height, artwork_scale)
			if normalized == null:
				return _fail("Empty or invalid crop artwork: " + source_name)
			var normalized_path: String = GENERATED_DIR + "/" + source_name + ".res"
			var texture: ImageTexture = ImageTexture.create_from_image(normalized)
			texture.resource_name = source_name
			if ResourceSaver.save(texture, normalized_path, ResourceSaver.FLAG_COMPRESS) != OK:
				return _fail("Could not save normalized texture: " + normalized_path)
			texture.take_over_path(normalized_path)
			filesystem.update_file(normalized_path)

			var atlas: TileSetAtlasSource = TileSetAtlasSource.new()
			atlas.resource_name = source_name
			atlas.texture = texture
			atlas.texture_region_size = cell_size
			atlas.create_tile(Vector2i.ZERO)
			var frame_total: int = frames.size()
			if frame_total > 1:
				atlas.set_tile_animation_columns(Vector2i.ZERO, frame_total)
				atlas.set_tile_animation_frames_count(Vector2i.ZERO, frame_total)
				atlas.set_tile_animation_speed(Vector2i.ZERO, ANIMATION_FPS)
				for f: int in range(frame_total):
					atlas.set_tile_animation_frame_duration(Vector2i.ZERO, f, 1.0)
			atlas.get_tile_data(Vector2i.ZERO, 0).texture_origin = Normalizer.root_origin(normalized, cell_size.x)
			if source_id >= 0:
				tiles.remove_source(source_id)
			source_id = tiles.add_source(atlas, source_id)
			ids.append(source_id)
			coords.append(Vector2i.ZERO)

		if IMPORT_DISEASES:
			var disease_id: int = DISEASE_FOLDERS[crop_name][disease]
			var visual: DiseaseVisualSet = null
			for existing_visual: DiseaseVisualSet in crop.disease_visuals:
				if existing_visual != null and existing_visual.disease_id == disease_id:
					visual = existing_visual
			if visual == null:
				visual = DiseaseVisualSet.new()
				visual.disease_id = disease_id
				var visuals: Array[DiseaseVisualSet] = []
				visuals.assign(crop.disease_visuals)
				visuals.append(visual)
				crop.disease_visuals = visuals
			visual.stage_source_ids = ids
			visual.stage_atlas_coords = coords
		else:
			crop.set("growth_stage_source_ids", ids)
			crop.set("growth_stage_atlas_coords", coords)
		if ResourceSaver.save(crop, crop_path) != OK:
			return _fail("Could not save crop: " + crop_path)

	world.set("crop_layer", layer)
	var overlay: CanvasItem = world.get("crop_overlay") as CanvasItem
	if overlay != null and is_new:
		overlay.visible = false
	EditorInterface.mark_scene_as_unsaved()
	var uid_before: int = ResourceLoader.get_resource_uid(SCENE_PATH)
	EditorInterface.save_scene_as(SCENE_PATH, false)
	if ResourceLoader.get_resource_uid(SCENE_PATH) != uid_before:
		return _fail("Main scene UID changed unexpectedly.")
	filesystem.update_file(SCENE_PATH)
	print("CROP_GROWTH_SETUP_PASS - Animated strips generated and saved!")
	return 0


func _load_stage_frames(crop_name: String, stage: int) -> Array[Image]:
	var base_roots: Array[String] = [
		"res://assets/art/tilesets/crops_raw",
		"res://assets/art/tileset/crops_raw",
		"res://assets/art/tilesets/crops",
		"res://assets/art/tileset/crops"
	]
	var sub_folders: Array[String] = [
		"%s/stage_%d" % [crop_name, stage],
		"%s/%s_stage_%d" % [crop_name, crop_name, stage],
		"%s_stage_%d" % [crop_name, stage]
	]
	for root: String in base_roots:
		for sub: String in sub_folders:
			var dir_path: String = "%s/%s" % [root, sub]
			if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(dir_path)):
				continue
			var frames: Array[Image] = _try_read_frames_in_dir(dir_path)
			if not frames.is_empty():
				print("Found animation folder: " + dir_path)
				return frames

	# Fallback to single static PNG if 11-frame directory isn't found
	for root: String in base_roots:
		var static_path: String = "%s/%s/%s_stage_%d.png" % [root, crop_name, crop_name, stage]
		if FileAccess.file_exists(static_path):
			var static_img: Image = Image.new()
			if static_img.load_png_from_buffer(FileAccess.get_file_as_bytes(static_path)) == OK:
				print("Fallback to static PNG: " + static_path)
				return [Normalizer.prepare_frame(static_img)]
	return []


func _try_read_frames_in_dir(dir_path: String) -> Array[Image]:
	var frames: Array[Image] = []
	for f: int in range(FRAME_COUNT):
		var candidates: Array[String] = [
			"%s/frame%04d.png" % [dir_path, f],
			"%s/frame_%04d.png" % [dir_path, f],
			"%s/frame%02d.png" % [dir_path, f],
			"%s/frame_%02d.png" % [dir_path, f],
			"%s/%04d.png" % [dir_path, f]
		]
		var loaded: Image = null
		for path: String in candidates:
			if FileAccess.file_exists(path):
				var img: Image = Image.new()
				if img.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) == OK:
					loaded = img
					break
		if loaded == null:
			return []
		frames.append(Normalizer.prepare_frame(loaded))
	return frames


func _find_source(tiles: TileSet, source_name: String) -> int:
	for index: int in range(tiles.get_source_count()):
		var source_id: int = tiles.get_source_id(index)
		var atlas: TileSetAtlasSource = tiles.get_source(source_id) as TileSetAtlasSource
		if atlas != null and atlas.resource_name == source_name:
			return source_id
	return -1


func _fail(message: String) -> int:
	push_error(message)
	print("SETUP FAILED: " + message)
	return 1

func _load_disease_frames(crop_name: String, disease: String, stage: int) -> Array[Image]:
	var directory: String = "res://assets/art/tilesets/crops_raw/%s/diseased/%s/stage_%d" % [crop_name, disease, stage]
	var names: PackedStringArray = DirAccess.get_files_at(directory)
	names.sort()
	var frames: Array[Image] = []
	for filename: String in names:
		if filename.begins_with("frame") and filename.ends_with(".png"):
			var source: Image = Image.new()
			if source.load_png_from_buffer(FileAccess.get_file_as_bytes(directory.path_join(filename))) != OK:
				return []
			frames.append(Normalizer.prepare_frame(source))
	return frames
