@tool
extends EditorScript
## Generates editable, simplified occluders for existing scenery atlas tiles.
func _run() -> void:
	await run_setup()

func run_setup() -> int:
	var tree: SceneTree = EditorInterface.get_base_control().get_tree()
	for frame: int in range(10):
		await tree.process_frame
	while EditorInterface.get_resource_filesystem().is_scanning():
		await tree.process_frame
	EditorInterface.open_scene_from_path("res://field_prototype.tscn")
	for frame: int in range(5):
		await tree.process_frame
	var scene: Node = EditorInterface.get_edited_scene_root()
	var world: Node = scene.get_node("World")
	var count: int = 0
	for layer_name: String in ["Foliage", "Trees"]:
		var layer: TileMapLayer = world.get_node(layer_name) as TileMapLayer
		var tiles: TileSet = layer.tile_set
		if tiles.get_occlusion_layers_count() == 0:
			tiles.add_occlusion_layer()
		tiles.set_occlusion_layer_light_mask(0, 2)
		layer.occlusion_enabled = true
		for source_index: int in range(tiles.get_source_count()):
			var atlas: TileSetAtlasSource = tiles.get_source(tiles.get_source_id(source_index)) as TileSetAtlasSource
			if atlas == null or atlas.resource_name not in ["foliage", "tree"]:
				continue
			var image: Image = atlas.texture.get_image()
			if image.is_compressed():
				image.decompress()
			for tile_index: int in range(atlas.get_tiles_count()):
				var coords: Vector2i = atlas.get_tile_id(tile_index)
				var data: TileData = atlas.get_tile_data(coords, 0)
				if data.get_occluder(0) != null:
					continue # Preserve hand-edited shapes on subsequent runs.
				var region: Rect2i = atlas.get_tile_texture_region(coords)
				var bitmap: BitMap = BitMap.new()
				bitmap.create_from_image_alpha(image.get_region(region), 0.3)
				var outlines: Array[PackedVector2Array] = bitmap.opaque_to_polygons(Rect2i(Vector2i.ZERO, region.size), 6.0)
				var points: PackedVector2Array = PackedVector2Array()
				for outline: PackedVector2Array in outlines:
					points.append_array(outline)
				if points.size() < 3:
					continue
				# Eight support points bound GPU work independently of leaf detail.
				var simple: PackedVector2Array = PackedVector2Array()
				for direction_index: int in range(8):
					var direction: Vector2 = Vector2.RIGHT.rotated(TAU * float(direction_index) / 8.0)
					var best: Vector2 = points[0]
					for point: Vector2 in points:
						if point.dot(direction) > best.dot(direction):
							best = point
					if not simple.has(best):
						simple.append(best)
				var hull: PackedVector2Array = Geometry2D.convex_hull(simple)
				if hull.size() < 4:
					continue
				hull.remove_at(hull.size() - 1)
				for index: int in range(hull.size()):
					hull[index] -= Vector2(region.size) * 0.5 + Vector2(data.texture_origin)
				var occluder: OccluderPolygon2D = OccluderPolygon2D.new()
				occluder.polygon = hull
				data.set_occluder(0, occluder)
				count += 1
		if not tiles.resource_path.contains("::") and not tiles.resource_path.is_empty():
			if ResourceSaver.save(tiles) != OK:
				return 1
	var light: PointLight2D = world.get_node("Lighting/SoftLight") as PointLight2D
	light.shadow_enabled = true
	light.shadow_item_cull_mask = 2
	light.shadow_filter = Light2D.SHADOW_FILTER_PCF5
	light.shadow_filter_smooth = 1.5
	light.shadow_color = Color(0.08, 0.10, 0.16, 0.65)
	light.editor_description = "Soft scenery shadows: PCF5. Adjust Shadow Filter Smooth and Color alpha. Occluder mask uses layer 2."
	# Keep the global fill unshadowed: directional 2D shadows extend infinitely.
	(world.get_node("Lighting/Sunlight") as DirectionalLight2D).shadow_enabled = false
	EditorInterface.mark_scene_as_unsaved()
	EditorInterface.save_scene_as("res://field_prototype.tscn", false)
	print("SCENERY_SHADOW_SETUP_PASS: ", count, " new tile occluders")
	return 0
