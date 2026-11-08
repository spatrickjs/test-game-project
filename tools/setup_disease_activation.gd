@tool
extends EditorScript
## Adds only activation/session wiring, using native Editor serialization.

func _run() -> void:
	await run_setup()

func run_setup() -> int:
	var tree: SceneTree = EditorInterface.get_base_control().get_tree()
	for frame: int in range(10):
		await tree.process_frame
	while EditorInterface.get_resource_filesystem().is_scanning():
		await tree.process_frame
	var scene_path: String = "res://field_prototype.tscn"
	EditorInterface.open_scene_from_path(scene_path)
	for frame: int in range(5):
		await tree.process_frame
	var scene: Node = EditorInterface.get_edited_scene_root()
	if scene == null or scene.scene_file_path != scene_path:
		return 1
	var turns: Node = scene.get("turn_controller") as Node
	if turns == null:
		return 1
	var policy_path: String = "res://src/data/resources/disease_activation/default_activation_policy.tres"
	if not FileAccess.file_exists(policy_path):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(policy_path.get_base_dir()))
		var policy: DiseaseActivationPolicy = DiseaseActivationPolicy.new()
		if ResourceSaver.save(policy, policy_path) != OK:
			return 1
		EditorInterface.get_resource_filesystem().update_file(policy_path)
		for frame: int in range(3):
			await tree.process_frame
	var activation: Node = turns.get("disease_activation_controller") as Node
	if activation == null:
		activation = scene.get_node_or_null("DiseaseActivationController")
		if activation == null:
			activation = Node.new()
			activation.name = "DiseaseActivationController"
			activation.set_script(load("res://src/logic/environment/disease_activation_controller.gd"))
			scene.add_child(activation)
			activation.owner = scene
	if activation.get_script() != load("res://src/logic/environment/disease_activation_controller.gd"):
		push_error("Existing activation node has an incompatible script.")
		return 1
	if activation.get("policy") == null:
		activation.set("policy", load(policy_path))
	turns.set("disease_activation_controller", activation)
	var manager: Node = scene.get("game_state_manager") as Node
	if manager == null:
		manager = Node.new()
		manager.name = "GameStateManager"
		manager.set_script(load("res://src/logic/turns/game_state_manager.gd"))
		scene.add_child(manager)
		manager.owner = scene
	scene.set("game_state_manager", manager)
	turns.set("game_state_manager", manager)
	var uid: int = ResourceLoader.get_resource_uid(scene_path)
	EditorInterface.mark_scene_as_unsaved()
	EditorInterface.save_scene_as(scene_path, false)
	if ResourceLoader.get_resource_uid(scene_path) != uid:
		return 1
	print("DISEASE_ACTIVATION_SETUP_PASS")
	return 0
