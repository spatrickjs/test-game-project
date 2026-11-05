@tool
class_name FieldTerrainPreview
extends Node2D
## Editor-only rendering. References Node placeholders to avoid running gameplay.
## The generated layer has no scene owner and is never serialized.

@export var preview_enabled: bool = true
@export var field_configuration: Node
@export var world_view: Node
@export_tool_button("Refresh terrain preview") var refresh_action: Callable = refresh_preview

var last_error: String = ""
var _preview_layer: TileMapLayer
var _last_signature: Array = []
var _elapsed: float = 0.0
var _watched_tileset: TileSet

func _ready() -> void:
	set_process(Engine.is_editor_hint())
	if Engine.is_editor_hint():
		refresh_preview.call_deferred()

func _process(delta: float) -> void:
	# Preview polling only; never runs crop, weather, or other simulation updates.
	_elapsed += delta
	if _elapsed < 0.25:
		return
	_elapsed = 0.0
	var signature: Array = _configuration_signature()
	if signature != _last_signature:
		refresh_preview()

func _configuration_signature() -> Array:
	var values: Array = [preview_enabled, field_configuration, world_view]
	if not is_instance_valid(field_configuration) or not is_instance_valid(world_view):
		return values
	var dimensions: Variant = field_configuration.get("field_size")
	var bands: Variant = field_configuration.get("terrain_bands")
	values.append(dimensions)
	values.append(bands.duplicate() if bands is Array else bands)
	var terrain: TileMapLayer = world_view.get("terrain_layer") as TileMapLayer
	var mapping: TerrainTileVisualMap = world_view.get("visual_map") as TerrainTileVisualMap
	values.append(terrain)
	values.append(mapping)
	if terrain != null:
		values.append(terrain.tile_set)
		values.append(terrain.global_transform)
		values.append(global_transform)
	if mapping != null:
		for entry: TerrainTileVisual in mapping.entries:
			if entry == null:
				values.append(null)
			else:
				values.append([entry.terrain_type, entry.source_id, entry.atlas_coords, entry.alternative_tile])
	return values

func refresh_preview() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	_last_signature = _configuration_signature()
	last_error = ""
	update_configuration_warnings.call_deferred()
	if _preview_layer != null:
		_preview_layer.clear()
	if not preview_enabled:
		return
	if not is_instance_valid(field_configuration) or not is_instance_valid(world_view):
		last_error = "Assign field_configuration and world_view."
		return
	var terrain: TileMapLayer = world_view.get("terrain_layer") as TileMapLayer
	var mapping: TerrainTileVisualMap = world_view.get("visual_map") as TerrainTileVisualMap
	if terrain == null or mapping == null or terrain.tile_set == null:
		last_error = "Assign the world's terrain layer, TileSet and visual map."
		return
	var dimensions: Vector2i = field_configuration.get("field_size")
	var bands: Array = field_configuration.get("terrain_bands")
	if dimensions.x < 1 or dimensions.y < 1 or bands.is_empty():
		last_error = "Field dimensions must be positive and terrain bands nonempty."
		return
	# Avoid editor stalls from accidentally entering huge Inspector dimensions.
	if float(dimensions.x) * float(dimensions.y) > 10000.0:
		last_error = "Editor preview is limited to 10,000 tiles; runtime configuration is unchanged."
		return
	var errors: PackedStringArray = mapping.validate(terrain.tile_set)
	for band: int in bands:
		if mapping.get_visual(band as SimulationEnums.TerrainType) == null:
			errors.append("Missing visual mapping for terrain %d." % band)
	if not errors.is_empty():
		last_error = "\n".join(errors)
		return
	if _preview_layer == null:
		_preview_layer = TileMapLayer.new()
		_preview_layer.name = "GeneratedTerrainPreview"
		add_child(_preview_layer, false, Node.INTERNAL_MODE_BACK)
		_preview_layer.owner = null
	_preview_layer.tile_set = terrain.tile_set
	# Convert the source terrain transform into this preview node's local space.
	_preview_layer.transform = global_transform.affine_inverse() * terrain.global_transform
	_preview_layer.y_sort_enabled = true
	if _watched_tileset != terrain.tile_set:
		if _watched_tileset != null and _watched_tileset.changed.is_connected(_on_tileset_changed):
			_watched_tileset.changed.disconnect(_on_tileset_changed)
		_watched_tileset = terrain.tile_set
		_watched_tileset.changed.connect(_on_tileset_changed)
	for y: int in range(dimensions.y):
		for x: int in range(dimensions.x):
			var band_index: int = mini(floori(float(x) * float(bands.size()) / float(dimensions.x)), bands.size() - 1)
			var visual: TerrainTileVisual = mapping.get_visual(bands[band_index] as SimulationEnums.TerrainType)
			_preview_layer.set_cell(Vector2i(x, y), visual.source_id, visual.atlas_coords, visual.alternative_tile)

func _on_tileset_changed() -> void:
	refresh_preview.call_deferred()

func get_preview_cell_count() -> int:
	return _preview_layer.get_used_cells().size() if _preview_layer != null else 0

func _exit_tree() -> void:
	if _watched_tileset != null and _watched_tileset.changed.is_connected(_on_tileset_changed):
		_watched_tileset.changed.disconnect(_on_tileset_changed)


func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray([last_error]) if not last_error.is_empty() else PackedStringArray()
