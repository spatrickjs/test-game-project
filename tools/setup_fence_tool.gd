@tool
extends EditorScript
## Idempotent scene wiring for the Fence tool. Runs the HUD baker, creates the
## World/FenceLayer with its own TileSet, saves fence_visual.tres, and wires both
## onto FieldWorldView. Reruns preserve authored fence art and transforms.

const Baker: Script = preload("res://tools/bake_ui_to_scene.gd")
const SCENE_PATH: String = "res://field_prototype.tscn"
const FENCE_PNG: String = "res://assets/art/tilesets/fence/fence.png"
const FENCE_VISUAL_PATH: String = "res://src/presentation/world/fence_visual.tres"
const FENCE_TILESET_PATH: String = "res://src/presentation/world/fence_tile_set.tres"


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


## Only initialize new layers. Reruns preserve authored tiles, resources and transforms.
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
	# Own TileSet with terrain geometry settings, so fence art is decoupled from terrain/crop art.
	# Saved as a standalone .tres so the atlas source (texture + tile) serializes fully.
	var tile_set: TileSet = load(FENCE_TILESET_PATH) as TileSet
	if tile_set == null:
		tile_set = TileSet.new()
		tile_set.tile_shape = terrain.tile_set.tile_shape
		tile_set.tile_layout = terrain.tile_set.tile_layout
		tile_set.tile_offset_axis = terrain.tile_set.tile_offset_axis
		tile_set.tile_size = terrain.tile_set.tile_size
	if not tile_set.has_source(0):
		var texture: Texture2D = load(FENCE_PNG)
		if texture == null:
			push_error("Fence PNG not found at " + FENCE_PNG)
			return
		var source: TileSetAtlasSource = TileSetAtlasSource.new()
		source.texture = texture
		source.texture_region_size = tile_set.tile_size
		tile_set.add_source(source, 0)
		source.create_tile(Vector2i.ZERO)
	var ts_err: int = ResourceSaver.save(tile_set, FENCE_TILESET_PATH)
	if ts_err != OK:
		push_error("Could not save fence TileSet (error %d)." % ts_err)
		return
	fence_layer.tile_set = tile_set
	# Z-order in the crop/actor tier, so fences sort with crops and the farmer.
	var crops: TileMapLayer = world.get("crop_layer") as TileMapLayer
	var shadows: Node2D = world.get_node_or_null("CropShadows") as Node2D
	var selection: Node2D = world.get_node_or_null("SelectionOverlay") as Node2D
	fence_layer.y_sort_enabled = true
	if crops != null:
		fence_layer.z_index = crops.z_index
	elif shadows != null:
		fence_layer.z_index = shadows.z_index + 1
	# Create or load the FenceVisual resource pointing at the single atlas source.
	var fence_visual: FenceVisual = load(FENCE_VISUAL_PATH) as FenceVisual
	if fence_visual == null:
		fence_visual = FenceVisual.new()
		fence_visual.source_id = 0
		fence_visual.atlas_coords = Vector2i.ZERO
		fence_visual.alternative_tile = 0
		var err: int = ResourceSaver.save(fence_visual, FENCE_VISUAL_PATH)
		if err != OK:
			push_error("Could not save fence_visual.tres (error %d)." % err)
			return
	# Transform follows the terrain layer.
	fence_layer.global_transform = terrain.global_transform
	world.set("fence_layer", fence_layer)
	world.set("fence_visual", fence_visual)
