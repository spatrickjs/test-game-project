class_name FieldWorldView
extends Node2D
## Converts input to logical intent and renders detached snapshots.

signal cell_clicked(coordinates: Vector2i)

@export var terrain_layer: TileMapLayer
@export var visual_map: TerrainTileVisualMap
@export var debug_clicks: bool = true
@export var crop_overlay: CropDebugOverlay
@export var crop_layer: TileMapLayer
@export var camera: Camera2D
@export var camera_margin_pixels: float = 32.0
@export var hud_reserved_height: float = 180.0

var last_error: String = ""
var _snapshot: FieldGridState = null
var _input_enabled: bool = false


func _ready() -> void:
	set_process_unhandled_input(_input_enabled)


func validate_configuration() -> PackedStringArray:
	var errors: PackedStringArray = _validate_terrain_configuration()
	if camera == null:
		errors.append("World: assign camera.")
	if crop_overlay == null:
		errors.append("World: assign crop_overlay.")
	elif crop_overlay.terrain_layer != terrain_layer:
		errors.append("CropOverlay: assign the same terrain_layer as World.")
	return errors


func _validate_terrain_configuration() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if terrain_layer == null:
		errors.append("World: assign terrain_layer.")
	if visual_map == null:
		errors.append("World: assign visual_map.")
	if terrain_layer != null and visual_map != null:
		errors.append_array(visual_map.validate(terrain_layer.tile_set))
		if terrain_layer.tile_set != null:
			if terrain_layer.tile_set.tile_shape != TileSet.TILE_SHAPE_ISOMETRIC:
				errors.append("Terrain TileSet must use Isometric tile shape.")
			if terrain_layer.tile_set.tile_layout != TileSet.TILE_LAYOUT_DIAMOND_RIGHT:
				errors.append("Terrain TileSet must use Diamond Right tile layout.")
	return errors


func render_field(snapshot: FieldGridState, crops: CropDatabase) -> bool:
	set_interaction_enabled(false)
	var errors: PackedStringArray = validate_configuration()
	if snapshot == null or crops == null:
		errors.append("World: a grid snapshot and crop catalog are required.")
	if not errors.is_empty():
		last_error = "\n".join(errors)
		return false
	if not render_grid(snapshot):
		return false
	if not render_crops(_snapshot, crops):
		return false
	crop_overlay.show_snapshot(_snapshot, crops)
	camera.enabled = true
	camera.position_smoothing_enabled = false
	frame_field()
	return true


## Terrain-only entry point. Requires only terrain_layer and visual_map.
## Returns false with last_error on invalid configuration; never mutates input.
func render_grid(grid_state: FieldGridState) -> bool:
	set_interaction_enabled(false)
	var errors: PackedStringArray = _validate_terrain_configuration()
	if grid_state == null:
		errors.append("World: grid_state is required.")
	if not errors.is_empty():
		last_error = "\n".join(errors)
		push_error(last_error)
		return false
	errors = grid_state.validate()
	if not errors.is_empty():
		last_error = "\n".join(errors)
		push_error(last_error)
		return false
	for y: int in range(grid_state.height):
		for x: int in range(grid_state.width):
			var cell: FieldCellState = grid_state.get_cell(Vector2i(x, y))
			if cell == null:
				continue
			if visual_map.get_visual(cell.terrain_type) == null:
				errors.append("No visual mapping for terrain %d." % cell.terrain_type)
	if not errors.is_empty():
		last_error = "\n".join(errors)
		push_error(last_error)
		return false
	terrain_layer.clear()
	# Raised tile side faces need back-to-front ordering.
	terrain_layer.y_sort_enabled = true
	for y: int in range(grid_state.height):
		for x: int in range(grid_state.width):
			var cell: FieldCellState = grid_state.get_cell(Vector2i(x, y))
			var visual: TerrainTileVisual = visual_map.get_visual(cell.terrain_type)
			terrain_layer.set_cell(cell.coordinates, visual.source_id, visual.atlas_coords, visual.alternative_tile)
	_snapshot = grid_state.copy()
	last_error = ""
	set_interaction_enabled(true)
	return true


func refresh_crops(snapshot: FieldGridState, crops: CropDatabase) -> void:
	_snapshot = snapshot
	render_crops(snapshot, crops)
	if crop_overlay != null:
		crop_overlay.show_snapshot(snapshot, crops)


## Visual stage only; logical growth/maturity remains owned by Logic/Data.
static func get_growth_stage(elapsed: int, duration: int) -> int:
	if duration < 1:
		return 0
	if elapsed >= duration:
		return 3
	var progress: float = clampf(float(elapsed) / float(duration), 0.0, 1.0)
	return clampi(int(floor(progress * 3.0)), 0, 2)


func validate_crop_visuals(crops: CropDatabase) -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if crop_layer == null:
		return errors # Legacy/debug-only scenes remain usable.
	if crop_layer.tile_set == null or crops == null:
		errors.append("Crops: assign a TileSet and crop catalog.")
		return errors
	for crop: CropData in crops.crops:
		if crop == null:
			errors.append("Crops: catalog contains a null crop.")
			continue
		if crop.growth_stage_source_ids.size() != 4 or crop.growth_stage_atlas_coords.size() != 4:
			errors.append("%s: both growth visual arrays must contain four entries." % crop.display_name)
			continue
		if crop.growth_ticks < 1:
			errors.append("%s: growth_ticks must be positive." % crop.display_name)
		for stage: int in range(4):
			var source_id: int = crop.growth_stage_source_ids[stage]
			if not crop_layer.tile_set.has_source(source_id):
				errors.append("%s stage %d: missing source %d." % [crop.display_name, stage, source_id])
				continue
			var atlas: TileSetAtlasSource = crop_layer.tile_set.get_source(source_id) as TileSetAtlasSource
			if atlas == null or not atlas.has_tile(crop.growth_stage_atlas_coords[stage]):
				errors.append("%s stage %d: missing atlas tile." % [crop.display_name, stage])
	return errors


## Validate before drawing, erase vacant cells, then refresh occupied tiles.
func render_crops(snapshot: FieldGridState, crops: CropDatabase) -> bool:
	if crop_layer == null:
		return true
	var errors: PackedStringArray = validate_crop_visuals(crops)
	if snapshot == null:
		errors.append("Crops: a snapshot is required.")
	if not errors.is_empty():
		last_error = "\n".join(errors)
		return false
	for y: int in range(snapshot.height):
		for x: int in range(snapshot.width):
			var cell: FieldCellState = snapshot.get_cell(Vector2i(x, y))
			if cell != null and cell.has_crop and not crops.has_crop(cell.crop_type):
				last_error = "Crops: occupied cell has no crop definition."
				return false
	for coordinates: Vector2i in crop_layer.get_used_cells():
		var existing: FieldCellState = snapshot.get_cell(coordinates)
		if existing == null or not existing.has_crop:
			crop_layer.erase_cell(coordinates)
	for y: int in range(snapshot.height):
		for x: int in range(snapshot.width):
			var cell: FieldCellState = snapshot.get_cell(Vector2i(x, y))
			if cell == null or not cell.has_crop:
				continue
			var crop: CropData = crops.get_crop(cell.crop_type)
			var stage: int = get_growth_stage(cell.growth_elapsed_ticks, crop.growth_ticks)
			crop_layer.set_cell(cell.coordinates, crop.growth_stage_source_ids[stage], crop.growth_stage_atlas_coords[stage])
	last_error = ""
	return true


func set_interaction_enabled(enabled: bool) -> void:
	_input_enabled = enabled and _snapshot != null
	set_process_unhandled_input(_input_enabled)


## Convert the event's viewport position to world space, then Terrain-local
## space. Using the event avoids stale OS mouse positions in embedded playtests.
func get_cell_at_viewport_position(viewport_position: Vector2) -> Vector2i:
	if terrain_layer == null:
		return Vector2i(-1, -1)
	var global_position_for_event: Vector2 = (
		terrain_layer.get_canvas_transform().affine_inverse() * viewport_position
	)
	var local_position: Vector2 = terrain_layer.to_local(global_position_for_event)
	return terrain_layer.local_to_map(local_position)


func frame_field() -> void:
	if _snapshot == null or camera == null or terrain_layer == null:
		return
	var bounds: Rect2 = Rect2()
	var has_bounds: bool = false
	for y: int in range(_snapshot.height):
		for x: int in range(_snapshot.width):
			var cell: FieldCellState = _snapshot.get_cell(Vector2i(x, y))
			var visual: TerrainTileVisual = visual_map.get_visual(cell.terrain_type)
			var atlas: TileSetAtlasSource = terrain_layer.tile_set.get_source(visual.source_id) as TileSetAtlasSource
			var data: TileData = atlas.get_tile_data(visual.atlas_coords, visual.alternative_tile)
			var region_size: Vector2 = Vector2(atlas.get_tile_texture_region(visual.atlas_coords).size)
			var top_left: Vector2 = (
				terrain_layer.map_to_local(cell.coordinates)
				- region_size * 0.5 - Vector2(data.texture_origin)
			)
			var corners: Array[Vector2] = [
				top_left, top_left + Vector2(region_size.x, 0.0),
				top_left + region_size, top_left + Vector2(0.0, region_size.y),
			]
			for corner: Vector2 in corners:
				var point: Vector2 = terrain_layer.to_global(corner)
				if not has_bounds:
					bounds = Rect2(point, Vector2.ZERO)
					has_bounds = true
				else:
					bounds = bounds.expand(point)
	if not has_bounds:
		return
	bounds = bounds.grow(32.0)
	var viewport_size: Vector2 = get_viewport_rect().size
	var margin: float = maxf(0.0, camera_margin_pixels)
	var reserved: float = clampf(hud_reserved_height, 0.0, viewport_size.y * 0.45)
	var available: Vector2 = Vector2(
		maxf(1.0, viewport_size.x - margin * 2.0),
		maxf(1.0, viewport_size.y - reserved - margin * 2.0)
	)
	var zoom_factor: float = maxf(0.01, minf(
		available.x / maxf(bounds.size.x, 1.0),
		available.y / maxf(bounds.size.y, 1.0)
	))
	camera.zoom = Vector2(zoom_factor, zoom_factor)
	camera.global_position = bounds.get_center() - Vector2(0.0, reserved * 0.5 / zoom_factor)
	camera.reset_smoothing()


func _unhandled_input(event: InputEvent) -> void:
	if not _input_enabled or terrain_layer == null:
		return
	var viewport_position: Vector2 = Vector2.ZERO
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		# Accept native AND emulated mouse input (including embedded playtests).
		if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
			return
		viewport_position = mouse_event.position
	elif event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event as InputEventScreenTouch
		# When mouse-from-touch is enabled, the mouse event is the single route.
		# Ignore touch-from-mouse events to avoid a second planting intent.
		if Input.emulate_mouse_from_touch or touch_event.device == -1:
			return
		if not touch_event.pressed or touch_event.index != 0:
			return
		viewport_position = touch_event.position
	else:
		return
	var coordinates: Vector2i = get_cell_at_viewport_position(viewport_position)
	if _snapshot == null or not _snapshot.is_in_bounds(coordinates):
		if debug_clicks:
			print("FieldWorldView: click outside field at ", coordinates)
		return
	if debug_clicks:
		print("FieldWorldView: cell_clicked (%d, %d)" % [coordinates.x, coordinates.y])
	cell_clicked.emit(coordinates)
	get_viewport().set_input_as_handled()
