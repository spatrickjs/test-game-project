@tool
extends EditorScript
const Baker: Script = preload("res://tools/bake_ui_to_scene.gd")
const SCENE_PATH: String = "res://field_prototype.tscn"


func _run() -> void:
	await run_setup()


func run_setup() -> int:
	var tree: SceneTree = EditorInterface.get_base_control().get_tree()
	for frame: int in range(10):
		await tree.process_frame
	while EditorInterface.get_resource_filesystem().is_scanning():
		await tree.process_frame
	EditorInterface.open_scene_from_path(SCENE_PATH)
	for frame: int in range(5):
		await tree.process_frame
	var scene: Node = EditorInterface.get_edited_scene_root()
	if scene == null or scene.scene_file_path != SCENE_PATH:
		push_error("Could not open field prototype.")
		return 1
	var baker: EditorScript = Baker.new() as EditorScript
	baker._run()
	if scene.get("remove_button") == null or scene.get("transfer_button") == null or scene.get("harvest_button") == null:
		push_error("Field tools could not be baked; scene not saved.")
		return 1
	var weather: Node = scene.get_node_or_null("WeatherManager")
	if weather == null:
		weather = Node.new()
		weather.name = "WeatherManager"
		weather.set_script(load("res://src/logic/environment/weather_manager.gd"))
		scene.add_child(weather)
		weather.owner = scene
	var soil_tools: Node = scene.get_node_or_null("SoilToolController")
	if soil_tools == null:
		soil_tools = Node.new()
		soil_tools.name = "SoilToolController"
		soil_tools.set_script(load("res://src/logic/farming/soil_tool_controller.gd"))
		scene.add_child(soil_tools)
		soil_tools.owner = scene
	soil_tools.set("farming_controller", scene.get("farming_controller"))
	scene.set("soil_tool_controller", soil_tools)
	(scene.get("turn_controller") as Node).set("weather_manager", weather)
	var world: Node = scene.get("world_view") as Node
	_setup_background_layers(scene, world)
	var agent: Node2D = world.get_node_or_null("FarmerAgent") as Node2D
	if agent == null:
		agent = Node2D.new()
		agent.name = "FarmerAgent"
		agent.set_script(load("res://src/presentation/world/farmer_agent.gd"))
		world.add_child(agent)
		agent.owner = scene
	var selection: Node2D = world.get_node_or_null("SelectionOverlay") as Node2D
	if selection == null:
		selection = Node2D.new()
		selection.name = "SelectionOverlay"
		selection.set_script(load("res://src/presentation/world/field_selection_overlay.gd"))
		world.add_child(selection)
		selection.owner = scene
	selection.set("terrain_layer", world.get("terrain_layer"))
	selection.z_index = 2
	world.set("farmer_agent", agent)
	world.set("selection_overlay", selection)
	world.set("y_sort_enabled", true)
	var crops: TileMapLayer = world.get("crop_layer") as TileMapLayer
	var shadows: Node2D = world.get_node_or_null("CropShadows") as Node2D
	if shadows == null:
		shadows = Node2D.new()
		shadows.name = "CropShadows"
		shadows.set_script(load("res://src/presentation/world/crop_shadow_overlay.gd"))
		world.add_child(shadows)
		shadows.owner = scene
		# Reserve a ground-detail tier above terrain and below the crop/actor tier.
		shadows.z_index = crops.z_index if crops != null else 1
		if crops != null:
			crops.z_index = shadows.z_index + 1
		selection.z_index = shadows.z_index + 2
	shadows.set("terrain_layer", world.get("terrain_layer"))
	world.set("crop_shadows", shadows)
	selection.z_index = maxi(selection.z_index, shadows.z_index + 2)
	if crops != null:
		crops.y_sort_enabled = true
		agent.z_index = crops.z_index
	var grass: TileMapLayer = world.get("grass_overlay_layer") as TileMapLayer
	if grass != null:
		grass.y_sort_enabled = true
		grass.z_index = agent.z_index
	var preview: Node = world.get_node_or_null("TerrainPreview")
	if preview == null:
		preview = Node2D.new()
		preview.name = "TerrainPreview"
		preview.set_script(load("res://src/presentation/world/field_terrain_preview.gd"))
		world.add_child(preview)
		preview.owner = scene
	preview.set("field_configuration", scene.get("farming_controller"))
	preview.set("world_view", world)
	preview.set("y_sort_enabled", true)
	preview.call("refresh_preview")
	var uid_before: int = ResourceLoader.get_resource_uid(SCENE_PATH)
	EditorInterface.mark_scene_as_unsaved()
	EditorInterface.save_scene_as(SCENE_PATH, false)
	if uid_before != ResourceLoader.get_resource_uid(SCENE_PATH):
		push_error("Scene UID changed unexpectedly.")
		return 1
	print("FIELD_TOOLS_SETUP_PASS")
	return 0


## Only initialize new layers. Reruns preserve authored tiles, resources and transforms.
func _setup_background_layers(scene: Node, world: Node) -> void:
	var terrain: TileMapLayer = world.get("terrain_layer") as TileMapLayer
	var names: Array[StringName] = [&"AutomaticGrassBackground", &"BackgroundTerrain", &"BackgroundDecorations"]
	var properties: Array[StringName] = [&"background_fill_layer", &"background_terrain_layer", &"background_decorations"]
	for index: int in range(names.size()):
		if index == 0 and not world.get("automatic_background_enabled"):
			continue # Manual-world setup intentionally removes the unused fill node.
		var layer: TileMapLayer = world.get_node_or_null(NodePath(names[index])) as TileMapLayer
		if layer == null:
			layer = TileMapLayer.new()
			layer.name = names[index]
			layer.transform = terrain.transform
			layer.z_index = terrain.z_index - 3 + index
			layer.y_sort_enabled = true
			# Give each editable layer its own TileSet so adding scenery cannot
			# accidentally modify the playable terrain's tile definitions.
			layer.tile_set = terrain.tile_set if index == 0 else terrain.tile_set.duplicate(true) as TileSet
			layer.collision_enabled = false
			layer.navigation_enabled = false
			world.add_child(layer)
			world.move_child(layer, index)
			layer.owner = scene
		world.set(properties[index], layer)
		# Ground must share a Y-sort tier so thick tile edges interleave naturally.
		if index < 2:
			layer.z_index = terrain.z_index
		elif layer.z_index == terrain.z_index - 1:
			var crops: TileMapLayer = world.get("crop_layer") as TileMapLayer
			layer.z_index = crops.z_index if crops != null else terrain.z_index + 2
