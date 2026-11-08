@tool
extends EditorScript
## Adds editable native lighting without rebuilding terrain or crop resources.

func _run() -> void:
	await run_setup()

func run_setup() -> int:
	var tree: SceneTree = EditorInterface.get_base_control().get_tree()
	for frame: int in range(10):
		await tree.process_frame
	while EditorInterface.get_resource_filesystem().is_scanning():
		await tree.process_frame
	var path: String = "res://field_prototype.tscn"
	EditorInterface.open_scene_from_path(path)
	for frame: int in range(5):
		await tree.process_frame
	var scene: Node = EditorInterface.get_edited_scene_root()
	if scene == null or scene.scene_file_path != path:
		return 1
	var world: Node = scene.get_node("World")
	if world.has_node("Lighting"):
		print("WORLD_LIGHTING_SETUP_PASS (already configured)")
		return 0
	var lighting: Node2D = Node2D.new()
	lighting.name = "Lighting"
	lighting.editor_description = "Adjust Ambient color, Sunlight color/energy, and SoftLight texture/scale/position. World only; HUD uses its own canvas."
	world.add_child(lighting)
	lighting.owner = scene
	var ambient: CanvasModulate = CanvasModulate.new()
	ambient.name = "Ambient"
	ambient.color = Color(0.72, 0.76, 0.83, 1.0)
	lighting.add_child(ambient)
	ambient.owner = scene
	var sun: DirectionalLight2D = DirectionalLight2D.new()
	sun.name = "Sunlight"
	sun.color = Color(1.0, 0.94, 0.83)
	sun.energy = 0.22
	sun.shadow_enabled = false
	lighting.add_child(sun)
	sun.owner = scene
	var light: PointLight2D = PointLight2D.new()
	light.name = "SoftLight"
	light.color = Color(1.0, 0.93, 0.78)
	light.energy = 0.18
	light.texture_scale = 8.0
	light.shadow_enabled = false
	var gradient: Gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.35, 0.7, 1.0])
	gradient.colors = PackedColorArray([Color.WHITE, Color(0.8, 0.8, 0.8), Color(0.28, 0.28, 0.28), Color.BLACK])
	gradient.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CUBIC
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.width = 512
	texture.height = 512
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	light.texture = texture
	light.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	lighting.add_child(light)
	light.owner = scene
	var terrain: TileMapLayer = world.get_node("Terrain") as TileMapLayer
	light.global_position = terrain.to_global(terrain.map_to_local(Vector2i(4, 4))) + Vector2(-350, -250)
	var uid: int = ResourceLoader.get_resource_uid(path)
	EditorInterface.mark_scene_as_unsaved()
	EditorInterface.save_scene_as(path, false)
	if ResourceLoader.get_resource_uid(path) != uid:
		return 1
	print("WORLD_LIGHTING_SETUP_PASS")
	return 0
