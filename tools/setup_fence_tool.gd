@tool
extends EditorScript
## Idempotent scene wiring for the Fence tool. Runs the HUD baker, creates the
## World/FenceLayer with its own TileSet, and wires both the layer and visual
## onto FieldWorldView using the authored fence atlas and connection mapping.

const Baker: Script = preload("res://tools/bake_ui_to_scene.gd")
const SCENE_PATH: String = "res://field_prototype.tscn"
const FENCE_TILE_SET: TileSet = preload("res://src/presentation/world/fence_tile_set.tres")
const FENCE_VISUAL: FenceVisual = preload("res://src/presentation/world/fence_visual.tres")


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
	if scene.get("fence_button") == null:
		push_error("Fence button could not be baked; scene not saved.")
		return 1
	var world: Node = scene.get("world_view") as Node
	_setup_fence_layer(scene, world)
	var uid_before: int = ResourceLoader.get_resource_uid(SCENE_PATH)
	EditorInterface.mark_scene_as_unsaved()
	EditorInterface.save_scene_as(SCENE_PATH, false)
	if uid_before != ResourceLoader.get_resource_uid(SCENE_PATH):
		push_error("Scene UID changed unexpectedly.")
		return 1
	print("FENCE_TOOL_SETUP_PASS")
	return 0


## Reuse the existing layer and wire it to the authored fence resources.
func _setup_fence_layer(scene: Node, world: Node) -> void:
	var terrain: TileMapLayer = world.get("terrain_layer") as TileMapLayer
	if terrain == null or terrain.tile_set == null:
		push_error("Terrain layer with TileSet required.")
		return
	var fence_layer: TileMapLayer = world.get_node_or_null("FenceLayer") as TileMapLayer
	if fence_layer == null:
		fence_layer = TileMapLayer.new()
		fence_layer.name = "FenceLayer"
		fence_layer.collision_enabled = false
		fence_layer.navigation_enabled = false
		world.add_child(fence_layer)
		fence_layer.owner = scene
	fence_layer.tile_set = FENCE_TILE_SET
	# Z-order in the crop/actor tier, so fences sort with crops and the farmer.
	var crops: TileMapLayer = world.get("crop_layer") as TileMapLayer
	var shadows: Node2D = world.get_node_or_null("CropShadows") as Node2D
	fence_layer.y_sort_enabled = true
	if crops != null:
		fence_layer.z_index = crops.z_index
	elif shadows != null:
		fence_layer.z_index = shadows.z_index + 1
	# Transform follows the terrain layer.
	fence_layer.global_transform = terrain.global_transform
	world.set("fence_layer", fence_layer)
	world.set("fence_visual", FENCE_VISUAL)
