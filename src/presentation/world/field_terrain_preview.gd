@tool
class_name FieldTerrainPreview
extends Node2D
## Editor-only rendering. References Node placeholders to avoid running gameplay.
## The generated layer has no scene owner and is never serialized.

@export var preview_enabled: bool = true
@export var background_preview_enabled: bool = true
@export_range(1, 30) var background_preview_padding: int = 10
@export var field_configuration: Node
@export var world_view: Node
@export_tool_button("Refresh terrain preview") var refresh_action: Callable = refresh_preview

var last_error: String = ""
var _preview_layer: TileMapLayer
var _background_preview_layer: TileMapLayer
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
	var values: Array = [preview_enabled, background_preview_enabled, background_preview_padding, field_configuration, world_view]
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
	values.append(world_view.get("automatic_background_enabled"))
	var authored: TileMapLayer = world_view.get("background_terrain_layer") as TileMapLayer
	if authored != null:
		values.append(authored.tile_map_data)
		values.append(authored.global_transform)
		values.append(authored.is_visible_in_tree())
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
	if _background_preview_layer != null:
		_background_preview_layer.clear()
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
	y_sort_enabled = true
	_preview_layer.z_index = terrain.z_index - z_index
	_refresh_background_preview(dimensions, terrain, mapping)
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

func _refresh_background_preview(dimensions: Vector2i, terrain: TileMapLayer, mapping: TerrainTileVisualMap) -> void:
	if not background_preview_enabled or not world_view.get("automatic_background_enabled"):
		return
	var grass: TerrainTileVisual = mapping.get_visual(SimulationEnums.TerrainType.GRASS)
	if grass == null:
		return
	if _background_preview_layer == null:
		_background_preview_layer = TileMapLayer.new()
		_background_preview_layer.name = "GeneratedBackgroundPreview"
		add_child(_background_preview_layer, false, Node.INTERNAL_MODE_BACK)
		_background_preview_layer.owner = null
	_background_preview_layer.tile_set = terrain.tile_set
	_background_preview_layer.transform = global_transform.affine_inverse() * terrain.global_transform
	_background_preview_layer.y_sort_enabled = true
	_background_preview_layer.z_index = terrain.z_index - z_index
	_background_preview_layer.collision_enabled = false
	_background_preview_layer.navigation_enabled = false
	var authored: TileMapLayer = world_view.get("background_terrain_layer") as TileMapLayer
	var padding: int = clampi(background_preview_padding, 1, 30)
	for y: int in range(-padding, dimensions.y + padding):
		for x: int in range(-padding, dimensions.x + padding):
			if x >= 0 and y >= 0 and x < dimensions.x and y < dimensions.y:
				continue
			var coords: Vector2i = Vector2i(x, y)
			if authored != null and authored.is_visible_in_tree():
				var authored_coords: Vector2i = authored.local_to_map(authored.to_local(terrain.to_global(terrain.map_to_local(coords))))
				if authored.get_cell_source_id(authored_coords) >= 0:
					continue
			_background_preview_layer.set_cell(coords, grass.source_id, grass.atlas_coords, grass.alternative_tile)

func _on_tileset_changed() -> void:
	refresh_preview.call_deferred()

func get_preview_cell_count() -> int:
	return _preview_layer.get_used_cells().size() if _preview_layer != null else 0

func _exit_tree() -> void:
	if _watched_tileset != null and _watched_tileset.changed.is_connected(_on_tileset_changed):
		_watched_tileset.changed.disconnect(_on_tileset_changed)


func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray([last_error]) if not last_error.is_empty() else PackedStringArray()
