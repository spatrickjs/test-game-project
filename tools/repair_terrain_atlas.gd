extends SceneTree
## One-time repair using Godot serialization, never raw scene-text replacement.
## Run with the editor closed or reload the scene afterward.

const SCENE_PATH: String = "res://field_prototype.tscn"


func _initialize() -> void:
	var scene: PackedScene = ResourceLoader.load(SCENE_PATH, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	if scene == null:
		quit(1)
		return
	var instance: Node = scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	var layer: TileMapLayer = instance.get_node("World/Terrain") as TileMapLayer
	var view: FieldWorldView = instance.get_node("World") as FieldWorldView
	# Godot rejects impossible serialized tiles at load. Remove any additional
	# valid-but-unused entries from these explicitly single-tile terrain sources.
	for entry: TerrainTileVisual in view.visual_map.entries:
		var atlas: TileSetAtlasSource = layer.tile_set.get_source(entry.source_id) as TileSetAtlasSource
		if atlas == null or entry.atlas_coords != Vector2i.ZERO or not atlas.has_tile(Vector2i.ZERO):
			push_error("Unexpected atlas configuration; scene not saved.")
			instance.free()
			quit(1)
			return
		# Invalid serialized properties can survive load in missing-property data.
		# Build a fresh single-tile source rather than resaving that stale object.
		var clean: TileSetAtlasSource = TileSetAtlasSource.new()
		clean.resource_name = atlas.resource_name
		clean.texture = atlas.texture
		clean.texture_region_size = atlas.texture_region_size
		clean.create_tile(Vector2i.ZERO)
		clean.get_tile_data(Vector2i.ZERO, 0).texture_origin = atlas.get_tile_data(Vector2i.ZERO, 0).texture_origin
		layer.tile_set.remove_source(entry.source_id)
		layer.tile_set.add_source(clean, entry.source_id)
	if not view.visual_map.validate(layer.tile_set).is_empty():
		instance.free()
		quit(1)
		return
	# Repack the same resource to retain its existing resource path/UID.
	var result: Error = scene.pack(instance)
	if result == OK:
		result = ResourceSaver.save(scene, SCENE_PATH)
	if result == OK:
		# Preserve the main-scene UID explicitly, also in headless runtime mode.
		var uid_text: String = str(ProjectSettings.get_setting("application/run/main_scene"))
		result = ResourceSaver.set_uid(SCENE_PATH, ResourceUID.text_to_id(uid_text))
	instance.free()
	if result == OK:
		print("TERRAIN_ATLAS_REPAIRED")
	quit(0 if result == OK else 1)
