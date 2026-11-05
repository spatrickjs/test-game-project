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
	var uid_before: int = ResourceLoader.get_resource_uid(SCENE_PATH)
	EditorInterface.mark_scene_as_unsaved()
	EditorInterface.save_scene_as(SCENE_PATH, false)
	if uid_before != ResourceLoader.get_resource_uid(SCENE_PATH):
		push_error("Scene UID changed unexpectedly.")
		return 1
	print("FIELD_TOOLS_SETUP_PASS")
	return 0
