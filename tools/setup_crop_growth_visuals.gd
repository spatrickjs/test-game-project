@tool
extends EditorScript
## Run in the editor, or with GODOT_CROP_VISUAL_SETUP=1 via the test harness.
## Uses Godot serialization only. Reuses a generated crop layer on repeat runs.

const SCENE_PATH: String = "res://field_prototype.tscn"
const Normalizer: Script = preload("res://tools/crop_texture_normalizer.gd")
const GENERATED_DIR: String = "res://assets/art/tilesets/crops/normalized"
const CROP_NAMES: Array[String] = ["rice", "corn", "sugarcane"]


func _run() -> void:
	await run_setup()


func run_setup() -> int:
	var tree: SceneTree = EditorInterface.get_base_control().get_tree()
	var filesystem: EditorFileSystem = EditorInterface.get_resource_filesystem()
	for frame: int in range(10):
		await tree.process_frame
	while filesystem.is_scanning():
		await tree.process_frame
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GENERATED_DIR)) != OK:
		return _fail("Could not create normalized texture directory.")
	EditorInterface.open_scene_from_path(SCENE_PATH)
	for frame: int in range(5):
		await tree.process_frame
	var scene: Node = EditorInterface.get_edited_scene_root()
	if scene == null or scene.scene_file_path != SCENE_PATH:
		return _fail("Could not open prototype scene.")
	var world: Node = scene.get("world_view") as Node
	var terrain: TileMapLayer = world.get("terrain_layer") as TileMapLayer
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
	for crop_name: String in CROP_NAMES:
		var crop_path: String = "res://src/data/resources/%s_data.tres" % crop_name
		var crop: Resource = load(crop_path)
		if crop == null:
			return _fail("Missing crop resource: " + crop_path)
		var ids: Array[int] = []
		var coords: Array[Vector2i] = []
		var originals: Array[Image] = []
		for stage: int in range(4):
			var path: String = "res://assets/art/tilesets/crops/%s/%s_stage_%d.png" % [crop_name, crop_name, stage]
			var original: Image = Image.new()
			if original.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) != OK:
				return _fail("Could not decode crop PNG: " + path)
			originals.append(original)
		var shared_height: float = Normalizer.shared_mature_height(originals, tiles.tile_size)
		if shared_height <= 0.0:
			return _fail("Invalid crop stage images: " + crop_name)
		for stage: int in range(4):
			var source_name: String = "%s_stage_%d" % [crop_name, stage]
			var source_id: int = _find_source(tiles, source_name)
			# Read original pixels, bypassing the old 256px import downscale.
			# Art-specific correction: shrink the drawn pixels before placing them
			# on the shared canvas. Root origin is measured from the final image.
			var artwork_scale: float = 0.5 if stage == 0 and crop_name in ["corn", "sugarcane"] else 1.0
			var normalized: Image = Normalizer.normalize(originals[stage], tiles.tile_size, stage, shared_height, artwork_scale)
			if normalized == null:
				return _fail("Empty or invalid crop artwork: " + source_name)
			var normalized_path: String = GENERATED_DIR + "/" + source_name + ".res"
			var texture: ImageTexture = ImageTexture.create_from_image(normalized)
			texture.resource_name = source_name
			# A Godot-native texture resource avoids a PNG reimport/cache race.
			if ResourceSaver.save(texture, normalized_path, ResourceSaver.FLAG_COMPRESS) != OK:
				return _fail("Could not save normalized texture: " + normalized_path)
			texture.take_over_path(normalized_path)
			filesystem.update_file(normalized_path)
			var atlas: TileSetAtlasSource = TileSetAtlasSource.new()
			atlas.resource_name = source_name
			atlas.texture = texture
			atlas.texture_region_size = normalized.get_size()
			atlas.create_tile(Vector2i.ZERO)
			atlas.get_tile_data(Vector2i.ZERO, 0).texture_origin = Normalizer.root_origin(normalized)
			if source_id >= 0:
				tiles.remove_source(source_id)
			source_id = tiles.add_source(atlas, source_id)
			ids.append(source_id)
			coords.append(Vector2i.ZERO)
		crop.set("growth_stage_source_ids", ids)
		crop.set("growth_stage_atlas_coords", coords)
		if ResourceSaver.save(crop, crop_path) != OK:
			return _fail("Could not save crop: " + crop_path)
	world.set("crop_layer", layer)
	# Register newly generated resource UIDs before saving scene references.
	filesystem.scan()
	while filesystem.is_scanning():
		await tree.process_frame
	var overlay: CanvasItem = world.get("crop_overlay") as CanvasItem
	if overlay != null and is_new:
		overlay.visible = false
	var uid_before: int = ResourceLoader.get_resource_uid(SCENE_PATH)
	EditorInterface.mark_scene_as_unsaved()
	EditorInterface.save_scene_as(SCENE_PATH, false)
	if ResourceLoader.get_resource_uid(SCENE_PATH) != uid_before:
		return _fail("Unexpected scene UID change.")
	print("CROP_GROWTH_SETUP_PASS")
	return 0


func _find_source(tiles: TileSet, source_name: String) -> int:
	for index: int in range(tiles.get_source_count()):
		var source_id: int = tiles.get_source_id(index)
		var atlas: TileSetAtlasSource = tiles.get_source(source_id) as TileSetAtlasSource
		if atlas != null and atlas.resource_name == source_name:
			return source_id
	return -1


func _fail(message: String) -> int:
	push_error(message)
	return 1
