@tool
extends EditorScript
## Idempotent scene wiring for the Fence tool. Runs the HUD baker, creates the
## World/FenceLayer with its own TileSet, saves fence_visual.tres, and wires both
## onto FieldWorldView. Reruns preserve authored fence art and transforms.
## Also authors 16 autotile atlas tiles from fence1.png (256×256 per tile) and
## populates FenceVisual.tile_mapping with the mask→atlas-coords mapping.

const Baker: Script = preload("res://tools/bake_ui_to_scene.gd")
const SCENE_PATH: String = "res://field_prototype.tscn"
const FENCE_PNG: String = "res://assets/art/tilesets/fence/fence.png"
const FENCE_AUTOTILE_PNG: String = "res://assets/art/tilesets/fence/fence1.png"
const FENCE_VISUAL_PATH: String = "res://src/presentation/world/fence_visual.tres"
const FENCE_TILESET_PATH: String = "res://src/presentation/world/fence_tile_set.tres"

## 16-entry table: index = reading order in fence1.png (row-major among the 16 occupied cells).
## Value = connection mask (N=1, E=2, S=4, W=8) the tile represents.
## Determined from visual analysis of the sprite sheet (fence1.png 2560×2560, 10×10 grid of 256×256 cells).
## Occupied cells in reading order: row6 cols0-4, row7 cols0-5, row8 cols0-4.
const MASK_TABLE: Array[int] = [
	15,  # m0  (0,6)  cross   N+E+S+W
	 7,  # m1  (1,6)  T       N+E+S
	11,  # m2  (2,6)  T       N+E+W
	14,  # m3  (3,6)  T       E+S+W
	13,  # m4  (4,6)  T       N+S+W
	 5,  # m5  (0,7)  straight N+S
	10,  # m6  (1,7)  straight E+W
	 3,  # m7  (2,7)  corner  N+E
	 6,  # m8  (3,7)  corner  E+S
	 9,  # m9  (4,7)  corner  N+W
	12,  # m10 (5,7)  corner  S+W
	 1,  # m11 (0,8)  end     N
	 2,  # m12 (1,8)  end     E
	 4,  # m13 (2,8)  end     S
	 8,  # m14 (3,8)  end     W
	 0,  # m15 (4,8)  post    (none)
]

## Corresponding atlas column,row in the 10×10 grid of 256×256 cells.
const TILE_POSITIONS: Array = [
	Vector2i(0, 6), Vector2i(1, 6), Vector2i(2, 6), Vector2i(3, 6), Vector2i(4, 6),
	Vector2i(0, 7), Vector2i(1, 7), Vector2i(2, 7), Vector2i(3, 7), Vector2i(4, 7),
	Vector2i(5, 7),
	Vector2i(0, 8), Vector2i(1, 8), Vector2i(2, 8), Vector2i(3, 8), Vector2i(4, 8),
]


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
	# Author the 16-tile autotile atlas from fence1.png into source id=2.
	# Preserve any other sources (legacy art in source 0, foliage in source 1 etc.).
	_ensure_autotile_source(tile_set, terrain)
	var ts_err: int = ResourceSaver.save(tile_set, FENCE_TILESET_PATH)
	if ts_err != OK:
		push_error("Could not save fence TileSet (error %d)." % ts_err)
		return
	fence_layer.tile_set = tile_set
	# Z-order in the crop/actor tier, so fences sort with crops and the farmer.
	var crops: TileMapLayer = world.get("crop_layer") as TileMapLayer
	var shadows: Node2D = world.get_node_or_null("CropShadows") as Node2D
	fence_layer.y_sort_enabled = true
	if crops != null:
		fence_layer.z_index = crops.z_index
	elif shadows != null:
		fence_layer.z_index = shadows.z_index + 1
	# Create or load the FenceVisual resource and populate the 16-entry tile_mapping.
	var fence_visual: FenceVisual = load(FENCE_VISUAL_PATH) as FenceVisual
	if fence_visual == null:
		fence_visual = FenceVisual.new()
	# Always set legacy fields to source 2 / post tile for backwards compat.
	fence_visual.source_id = 2
	fence_visual.atlas_coords = TILE_POSITIONS[15]  # post tile (mask 0)
	fence_visual.alternative_tile = 0
	# Populate tile_mapping: mask → [source_id, atlas_coords, alternative].
	var mapping: Dictionary = {}
	for i: int in range(MASK_TABLE.size()):
		var mask: int = MASK_TABLE[i]
		var coords: Vector2i = TILE_POSITIONS[i]
		mapping[mask] = [2, coords, 0]
	fence_visual.tile_mapping = mapping
	var err: int = ResourceSaver.save(fence_visual, FENCE_VISUAL_PATH)
	if err != OK:
		push_error("Could not save fence_visual.tres (error %d)." % err)
		return
	# Transform follows the terrain layer.
	fence_layer.global_transform = terrain.global_transform
	world.set("fence_layer", fence_layer)
	world.set("fence_visual", fence_visual)


## Creates or refreshes source id=2 as the 16-tile autotile atlas from fence1.png.
## Idempotent: removes and recreates the source when the texture changes but
## preserves authored art on other sources.
func _ensure_autotile_source(tile_set: TileSet, terrain: TileMapLayer) -> void:
	var texture: Texture2D = load(FENCE_AUTOTILE_PNG)
	if texture == null:
		push_error("Autotile PNG not found at " + FENCE_AUTOTILE_PNG)
		return
	const AUTOTILE_SOURCE_ID: int = 2
	const CELL_SIZE: int = 256  # each tile in fence1.png is 256×256 pixels
	# Remove stale source so we can recreate it cleanly.
	if tile_set.has_source(AUTOTILE_SOURCE_ID):
		tile_set.remove_source(AUTOTILE_SOURCE_ID)
	var source: TileSetAtlasSource = TileSetAtlasSource.new()
	source.resource_name = "fence_autotile"
	source.texture = texture
	source.texture_region_size = Vector2i(CELL_SIZE, CELL_SIZE)
	tile_set.add_source(source, AUTOTILE_SOURCE_ID)
	# Create one tile per mask entry.
	for i: int in range(TILE_POSITIONS.size()):
		var coords: Vector2i = TILE_POSITIONS[i]
		if not source.has_tile(coords):
			source.create_tile(coords)
