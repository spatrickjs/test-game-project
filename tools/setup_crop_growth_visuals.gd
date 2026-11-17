@tool
extends EditorScript
## Refresh the existing crop atlas sources from their imported animation strips.

const SCENE_PATH: String = "res://field_prototype.tscn"
const CROP_TEXTURES: String = "res://assets/art/tilesets/crops"
const FRAME_SIZE: Vector2i = Vector2i(216, 320)
const Normalizer: Script = preload("res://tools/crop_texture_normalizer.gd")


func _run() -> void:
	run_setup()


func run_setup() -> int:
	var scene: PackedScene = ResourceLoader.load(SCENE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	if scene == null:
		return _fail("Cannot load " + SCENE_PATH)
	var state: SceneState = scene.get_state()
	var tiles: TileSet
	for node_index: int in range(state.get_node_count()):
		if str(state.get_node_path(node_index)).trim_prefix("./") != "World/Crops":
			continue
		for property_index: int in range(state.get_node_property_count(node_index)):
			if state.get_node_property_name(node_index, property_index) == &"tile_set":
				tiles = state.get_node_property_value(node_index, property_index) as TileSet
	if tiles == null:
		return _fail("Cannot find the crop TileSet in " + SCENE_PATH)

	var textures: Dictionary[int, Texture2D] = {}
	var origins: Dictionary[int, Vector2i] = {}
	for index: int in range(tiles.get_source_count()):
		var source_id: int = tiles.get_source_id(index)
		var atlas: TileSetAtlasSource = tiles.get_source(source_id) as TileSetAtlasSource
		if atlas == null or atlas.get_tiles_count() != 1 or not atlas.has_tile(Vector2i.ZERO):
			return _fail("Unexpected crop atlas at source %d" % source_id)
		var source_name: String = atlas.resource_name
		var crop: String = source_name.get_slice("_", 0)
		var variant: String = source_name.trim_prefix(crop + "_").get_slice("_stage_", 0)
		if source_name.begins_with(crop + "_stage_"):
			variant = "healthy"
		var path: String = "%s/%s/%s/%s.png" % [CROP_TEXTURES, crop, variant, source_name]
		var texture: Texture2D = ResourceLoader.load(path, "Texture2D") as Texture2D
		var frames: int = atlas.get_tile_animation_frames_count(Vector2i.ZERO)
		if texture == null or texture.get_size() != Vector2(FRAME_SIZE.x * frames, FRAME_SIZE.y):
			return _fail("Expected %d frames of %s in %s" % [frames, FRAME_SIZE, path])

		var image: Image = texture.get_image()
		if image == null or (image.is_compressed() and image.decompress() != OK):
			return _fail("Cannot read " + path)
		if not image.get_region(Rect2i(Vector2i.ZERO, FRAME_SIZE)).get_used_rect().has_area():
			return _fail("Empty first frame in " + path)
		textures[source_id] = texture
		origins[source_id] = Normalizer.root_origin(image, FRAME_SIZE.x)

	for source_id: int in textures:
		var atlas: TileSetAtlasSource = tiles.get_source(source_id) as TileSetAtlasSource
		atlas.texture_region_size = FRAME_SIZE
		atlas.texture = textures[source_id]
		atlas.get_tile_data(Vector2i.ZERO, 0).texture_origin = origins[source_id]

	if ResourceSaver.save(scene, SCENE_PATH) != OK:
		return _fail("Cannot save " + SCENE_PATH)
	EditorInterface.get_resource_filesystem().update_file(SCENE_PATH)
	print("CROP_GROWTH_SETUP_PASS - Updated %d crop atlas sources" % textures.size())
	return 0


func _fail(message: String) -> int:
	push_error(message)
	return 1
