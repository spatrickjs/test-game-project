class_name FieldWorldView
extends Node2D
## Converts input to logical intent and renders detached snapshots.

signal cell_clicked(coordinates: Vector2i)
signal camera_view_changed
signal cells_selected(coordinates: Array[Vector2i], action_kind: int)

@export var terrain_layer: TileMapLayer
## Runtime-generated backdrop only. Never assign an authored scenery layer here.
@export var background_fill_layer: TileMapLayer
@export var automatic_background_enabled: bool = false
## Authored scenery is never cleared or painted by FieldWorldView.
@export var background_terrain_layer: TileMapLayer
@export var background_decorations: TileMapLayer
@export var visual_map: TerrainTileVisualMap
@export var debug_clicks: bool = true
@export var crop_overlay: CropDebugOverlay
@export var crop_layer: TileMapLayer
@export var crop_shadows: CropShadowOverlay
@export var camera: Camera2D
@export var farmer_agent: FarmerAgent
@export var selection_overlay: FieldSelectionOverlay
@export var camera_margin_pixels: float = 32.0
## World-space camera adjustment. Positive Y moves the rendered field upward.
@export var camera_center_offset: Vector2 = Vector2.ZERO
@export var hud_reserved_height: float = 180.0
@export_range(1.0, 10.0) var max_zoom_multiplier: float = 2.5
@export_range(1.01, 2.0) var wheel_zoom_factor: float = 1.15
@export var tap_drag_threshold: float = 10.0
@export var grass_overlay_layer: TileMapLayer
@export var animated_grass_source_id: int = 1       # The Source ID of your animated strip in the TileSet
@export var grass_tuft_atlas_coords: Vector2i = Vector2i(0, 0) # Coordinate of the first frame (usually 0,0)
@export_range(0.0, 1.0) var tuft_spawn_chance: float = 0.25

var min_zoom: float = 1.0
var max_zoom: float = 2.5
var _default_camera_center: Vector2 = Vector2.ZERO
var _touches: Dictionary[int, Vector2] = {}
var _tap_index: int = -1
var _tap_origin: Vector2 = Vector2.ZERO
var _mouse_down: bool = false
var _mouse_origin: Vector2 = Vector2.ZERO
var _mouse_last: Vector2 = Vector2.ZERO
var _mouse_dragged: bool = false
var _ui_controls: Array[Control] = []
var _blocked_touches: Dictionary[int, bool] = {}
var _gesture_blocked: bool = false

var last_error: String = ""
var _snapshot: FieldGridState = null
var _input_enabled: bool = false
var _tool_active: bool = false
var _multi_select: bool = false
var _eligible: Dictionary[Vector2i, int] = {}
var _selection: Array[Vector2i] = []
var _selection_kind: int = -1
var _selecting: bool = false
var _selection_last: Vector2 = Vector2.ZERO
var _middle_pan: bool = false


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
	var errors: PackedStringArray = _validate_terrain_configuration()
	if grid_state == null:
		errors.append("World: grid_state is required.")
	if not errors.is_empty():
		last_error = "\n".join(errors)
		push_error(last_error)
		set_interaction_enabled(false)
		return false
	errors = grid_state.validate()
	if not errors.is_empty():
		last_error = "\n".join(errors)
		push_error(last_error)
		set_interaction_enabled(false)
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
		set_interaction_enabled(false)
		return false
	terrain_layer.clear()
	# Raised tile side faces need back-to-front ordering.
	terrain_layer.y_sort_enabled = true
	for y: int in range(grid_state.height):
		for x: int in range(grid_state.width):
			var cell: FieldCellState = grid_state.get_cell(Vector2i(x, y))
			var visual: TerrainTileVisual = visual_map.get_visual(cell.terrain_type)
			terrain_layer.set_cell(cell.coordinates, visual.source_id, visual.atlas_coords, visual.alternative_tile)
	_render_cosmetic_border(grid_state)
	_render_grass_overlay(grid_state)
	_snapshot = grid_state.copy()
	last_error = ""
	set_interaction_enabled(true)
	return true


## Optional decoration only: use an independent, repeatable random stream.
func _render_grass_overlay(grid_state: FieldGridState) -> void:
	if grass_overlay_layer == null or grass_overlay_layer == terrain_layer or grass_overlay_layer == crop_layer:
		return
	grass_overlay_layer.clear()
	var tiles: TileSet = grass_overlay_layer.tile_set
	if tiles == null or not tiles.has_source(animated_grass_source_id):
		return
	var atlas: TileSetAtlasSource = tiles.get_source(animated_grass_source_id) as TileSetAtlasSource
	if atlas == null or not atlas.has_tile(grass_tuft_atlas_coords):
		return
	var decoration_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	decoration_rng.seed = 0
	for y: int in range(grid_state.height):
		for x: int in range(grid_state.width):
			var cell: FieldCellState = grid_state.get_cell(Vector2i(x, y))
			# Consume one value per coordinate so digging never relocates other tufts.
			var spawn: bool = decoration_rng.randf() < tuft_spawn_chance
			if cell.terrain_type == SimulationEnums.TerrainType.GRASS and spawn:
				grass_overlay_layer.set_cell(cell.coordinates, animated_grass_source_id, grass_tuft_atlas_coords)


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
	_align_crop_grid()
	if crop_shadows != null:
		crop_shadows.show_snapshot(snapshot)
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


## Crop artwork keeps its own atlas and root origins, but uses terrain geometry.
## Duplicate before changing geometry so shared authoring resources stay intact.
func _align_crop_grid() -> void:
	if crop_layer == null or crop_layer == terrain_layer or crop_layer.tile_set == null:
		return
	if terrain_layer == null or terrain_layer.tile_set == null:
		return
	var ground: TileSet = terrain_layer.tile_set
	var crops: TileSet = crop_layer.tile_set
	if crops.tile_size != ground.tile_size or crops.tile_shape != ground.tile_shape or crops.tile_layout != ground.tile_layout or crops.tile_offset_axis != ground.tile_offset_axis:
		crops = crops.duplicate() as TileSet
		crops.tile_shape = ground.tile_shape
		crops.tile_layout = ground.tile_layout
		crops.tile_offset_axis = ground.tile_offset_axis
		crops.tile_size = ground.tile_size
		crop_layer.tile_set = crops
	crop_layer.global_transform = terrain_layer.global_transform


func set_interaction_enabled(enabled: bool) -> void:
	_input_enabled = enabled and _snapshot != null
	set_process_unhandled_input(_input_enabled)
	if not _input_enabled:
		_reset_touch_gesture()
		_blocked_touches.clear()


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
	if _snapshot == null or camera == null or terrain_layer == null or terrain_layer.tile_set == null:
		return
	var bounds: Rect2 = Rect2()
	var has_bounds: bool = false
	var half_tile: Vector2 = Vector2(terrain_layer.tile_set.tile_size) * 0.5
	for y: int in range(_snapshot.height):
		for x: int in range(_snapshot.width):
			var cell: FieldCellState = _snapshot.get_cell(Vector2i(x, y))
			var center: Vector2 = terrain_layer.map_to_local(cell.coordinates)
			# Use the playable diamond, not transparent atlas padding or border cells.
			var corners: Array[Vector2] = [
				center + Vector2(-half_tile.x, 0.0), center + Vector2(half_tile.x, 0.0),
				center + Vector2(0.0, -half_tile.y), center + Vector2(0.0, half_tile.y),
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
	var viewport_size: Vector2 = get_viewport_rect().size
	var margin: float = maxf(0.0, camera_margin_pixels)
	var reserved: float = clampf(hud_reserved_height, 0.0, viewport_size.y * 0.45)
	var available: Vector2 = Vector2(
		maxf(1.0, viewport_size.x - margin * 2.0),
		maxf(1.0, viewport_size.y - reserved - margin * 2.0)
	)
	var zoom_factor: float = maxf(0.001, minf(
		available.x / maxf(bounds.size.x, 1.0),
		available.y / maxf(bounds.size.y, 1.0)
	))
	camera.zoom = Vector2(zoom_factor, zoom_factor)
	# The bottom HUD occupies screen space: move the camera DOWN to lift the field.
	_default_camera_center = bounds.get_center() + Vector2(0.0, reserved * 0.5 / zoom_factor) + camera_center_offset
	camera.global_position = _default_camera_center
	min_zoom = zoom_factor
	max_zoom = min_zoom * maxf(1.0, max_zoom_multiplier)
	_render_cosmetic_border(_snapshot)
	_reset_touch_gesture()
	_blocked_touches.clear()
	camera.reset_smoothing()
	camera.force_update_scroll()
	camera_view_changed.emit()

func _render_cosmetic_border(grid_state: FieldGridState) -> void:
	if background_fill_layer == null:
		return
	if background_fill_layer in [terrain_layer, crop_layer, grass_overlay_layer, background_terrain_layer, background_decorations]:
		return # A misassigned generated layer must never erase gameplay or artwork.
	background_fill_layer.clear()
	if not automatic_background_enabled:
		return
	background_fill_layer.tile_set = terrain_layer.tile_set
	background_fill_layer.global_transform = terrain_layer.global_transform
	background_fill_layer.z_index = terrain_layer.z_index
	background_fill_layer.y_sort_enabled = true
	var visual: TerrainTileVisual = visual_map.get_visual(SimulationEnums.TerrainType.GRASS)
	if visual == null:
		return

	# Keep the original border, extending it to cover the shifted overview.
	# Zoomed/panned views are clamped inside this same overview footprint.
	var padding: int = 10
	var minimum: Vector2i = Vector2i(-padding, -padding)
	var maximum: Vector2i = Vector2i(grid_state.width + padding, grid_state.height + padding)
	if camera != null and min_zoom > 0.0:
		var half_view: Vector2 = get_viewport_rect().size * 0.5 / min_zoom
		for direction: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			var corner: Vector2i = terrain_layer.local_to_map(terrain_layer.to_local(_default_camera_center + half_view * direction))
			minimum = minimum.min(corner - Vector2i(2, 2))
			maximum = maximum.max(corner + Vector2i(3, 3))
	for y: int in range(minimum.y, maximum.y):
		for x: int in range(minimum.x, maximum.x):
			var coords: Vector2i = Vector2i(x, y)

			# Only paint if this coordinate is OUTSIDE our actual playable farm grid
			if not grid_state.is_in_bounds(coords):
				if background_terrain_layer != null and background_terrain_layer.is_visible_in_tree():
					var authored_coords: Vector2i = background_terrain_layer.local_to_map(background_terrain_layer.to_local(terrain_layer.to_global(terrain_layer.map_to_local(coords))))
					if background_terrain_layer.get_cell_source_id(authored_coords) >= 0:
						continue
				background_fill_layer.set_cell(coords, visual.source_id, visual.atlas_coords, visual.alternative_tile)

## The visible rectangle always remains inside the original overview footprint.
func clamp_camera_position() -> void:
	if camera == null:
		return
	if is_equal_approx(camera.zoom.x, min_zoom):
		camera.global_position = _default_camera_center
		camera.force_update_scroll()
		return
	var extent: Vector2 = get_viewport_rect().size * 0.5 * maxf(0.0, 1.0 / min_zoom - 1.0 / camera.zoom.x)
	camera.global_position = camera.global_position.clamp(_default_camera_center - extent, _default_camera_center + extent)
	camera.force_update_scroll()


func apply_zoom_ratio(ratio: float, focal_position: Vector2 = Vector2.INF) -> void:
	if camera == null or not is_finite(ratio) or ratio <= 0.0:
		return
	var focal: Vector2 = get_viewport_rect().size * 0.5 if focal_position == Vector2.INF else focal_position
	var old_zoom: float = camera.zoom.x
	var zoom_value: float = clampf(old_zoom * ratio, min_zoom, max_zoom)
	camera.global_position += (focal - get_viewport_rect().size * 0.5) * (1.0 / old_zoom - 1.0 / zoom_value)
	camera.zoom = Vector2.ONE * zoom_value
	clamp_camera_position()
	camera_view_changed.emit()


func pan_camera(screen_delta: Vector2) -> void:
	if camera == null or not screen_delta.is_finite():
		return
	camera.global_position -= screen_delta / camera.zoom.x
	clamp_camera_position()


func toggle_inspection_zoom() -> void:
	_reset_touch_gesture()
	if camera == null:
		return
	if camera.zoom.x > min_zoom + 0.00001:
		apply_zoom_ratio(min_zoom / camera.zoom.x)
	else:
		apply_zoom_ratio(minf(1.8, max_zoom_multiplier))


func _reset_touch_gesture() -> void:
	_cancel_selection()
	_middle_pan = false
	_touches.clear()
	_tap_index = -1
	_gesture_blocked = false
	_mouse_down = false
	_mouse_dragged = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_reset_touch_gesture()
		_blocked_touches.clear()


## GUI-consumed events cancel ownership; they never move the camera or select.
## Native touches also receive explicit rect guards (mouse emulation may be off).
func register_ui_input_root(control: Control) -> void:
	if control.mouse_filter == Control.MOUSE_FILTER_STOP:
		if not _ui_controls.has(control):
			_ui_controls.append(control)
			control.gui_input.connect(_on_ui_input)
	for child: Node in control.get_children():
		if child is Control:
			register_ui_input_root(child as Control)


func _on_ui_input(event: InputEvent) -> void:
	if event is InputEventMouse or event is InputEventScreenTouch or event is InputEventScreenDrag:
		_cancel_for_ui(event)


func _cancel_for_ui(event: InputEvent) -> void:
	# Quarantine every involved finger until release; no mid-gesture re-entry.
	for index: int in _touches:
		_blocked_touches[index] = true
	_reset_touch_gesture()
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.device != -1:
			if touch.pressed:
				_blocked_touches[touch.index] = true
			else:
				_blocked_touches.erase(touch.index)
	elif event is InputEventScreenDrag and event.device != -1:
		_blocked_touches[(event as InputEventScreenDrag).index] = true


func _is_over_ui(screen_pos: Vector2) -> bool:
	for control: Control in _ui_controls:
		if not is_instance_valid(control) or not control.is_visible_in_tree():
			continue
		var local: Vector2 = control.get_global_transform_with_canvas().affine_inverse() * screen_pos
		if Rect2(Vector2.ZERO, control.size).has_point(local):
			return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if not _input_enabled or terrain_layer == null:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_MIDDLE:
		var middle: InputEventMouseButton = event as InputEventMouseButton
		_cancel_selection()
		_mouse_down = false
		_middle_pan = middle.pressed and not _is_over_ui(middle.position) and _touches.is_empty()
		_mouse_last = middle.position
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and _middle_pan:
		var middle_motion: InputEventMouseMotion = event as InputEventMouseMotion
		if _is_over_ui(middle_motion.position) or not (middle_motion.button_mask & MOUSE_BUTTON_MASK_MIDDLE):
			_reset_touch_gesture()
			return
		pan_camera(middle_motion.position - _mouse_last)
		_mouse_last = middle_motion.position
		get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.device == -1:
			return
		if not _blocked_touches.is_empty():
			if touch.pressed:
				_blocked_touches[touch.index] = true
			else:
				_blocked_touches.erase(touch.index)
			get_viewport().set_input_as_handled()
			return
		if _is_over_ui(touch.position):
			_cancel_for_ui(touch)
			get_viewport().set_input_as_handled()
			return
		if touch.pressed:
			_mouse_down = false
			_touches[touch.index] = touch.position
			if _touches.size() == 1 and not _gesture_blocked:
				_tap_index = touch.index
				_tap_origin = touch.position
				if _tool_active:
					_begin_selection(touch.position)
			else:
				_cancel_selection()
				_gesture_blocked = true
				_tap_index = -1
		else:
			var finish_selection: bool = _selecting and not touch.canceled and not _gesture_blocked and touch.index == _tap_index and _touches.size() == 1
			var is_tap: bool = (not touch.canceled and not _gesture_blocked
				and touch.index == _tap_index and _touches.size() == 1
				and touch.position.distance_to(_tap_origin) <= tap_drag_threshold)
			_touches.erase(touch.index)
			_tap_index = -1
			if _touches.is_empty():
				_gesture_blocked = false
			if finish_selection:
				_extend_selection(touch.position)
				_commit_selection()
			elif _tool_active:
				_cancel_selection()
			elif is_tap:
				_emit_cell_at(touch.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		if drag.device == -1:
			return
		if not _blocked_touches.is_empty():
			return
		if _is_over_ui(drag.position):
			_cancel_for_ui(drag)
			return
		if not _touches.has(drag.index):
			return
		var previous: Vector2 = _touches[drag.index]
		var indices: Array[int] = _touches.keys()
		if indices.size() == 2:
			var old_midpoint: Vector2 = (_touches[indices[0]] + _touches[indices[1]]) * 0.5
			var old_distance: float = _touches[indices[0]].distance_to(_touches[indices[1]])
			_touches[drag.index] = drag.position
			var new_midpoint: Vector2 = (_touches[indices[0]] + _touches[indices[1]]) * 0.5
			var new_distance: float = _touches[indices[0]].distance_to(_touches[indices[1]])
			# Zoom at the old midpoint, then move that same world point with the fingers.
			if old_distance > 1.0 and new_distance > 0.0:
				apply_zoom_ratio(new_distance / old_distance, old_midpoint)
			pan_camera(new_midpoint - old_midpoint)
		else:
			_touches[drag.index] = drag.position
			if indices.size() == 1:
				if _tool_active and _selecting:
					_extend_selection(drag.position)
				elif drag.position.distance_to(_tap_origin) > tap_drag_threshold:
					_gesture_blocked = true
					_tap_index = -1
				if _gesture_blocked and not _tool_active:
					pan_camera(drag.position - previous)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mouse: InputEventMouseButton = event as InputEventMouseButton
		if not _touches.is_empty() or not _blocked_touches.is_empty():
			return
		if _is_over_ui(mouse.position):
			_reset_touch_gesture()
			return
		if mouse.pressed and mouse.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			apply_zoom_ratio(wheel_zoom_factor if mouse.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / wheel_zoom_factor, mouse.position)
		elif mouse.button_index == MOUSE_BUTTON_LEFT:
			if mouse.pressed:
				_mouse_down = true
				_mouse_dragged = false
				_mouse_origin = mouse.position
				_mouse_last = mouse.position
				if _tool_active:
					_begin_selection(mouse.position)
			else:
				var is_click: bool = _mouse_down and not _mouse_dragged and mouse.position.distance_to(_mouse_origin) <= tap_drag_threshold
				_mouse_down = false
				if _tool_active and _selecting:
					_extend_selection(mouse.position)
					_commit_selection()
				elif is_click and not _tool_active:
					_emit_cell_at(mouse.position)
		else:
			return
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		if not _mouse_down or not _touches.is_empty():
			return
		if _is_over_ui(motion.position) or not (motion.button_mask & MOUSE_BUTTON_MASK_LEFT):
			_reset_touch_gesture()
			return
		if motion.position.distance_to(_mouse_origin) > tap_drag_threshold:
			_mouse_dragged = true
		if _tool_active and _selecting:
			_extend_selection(motion.position)
		elif _mouse_dragged and not _tool_active:
			pan_camera(motion.position - _mouse_last)
		_mouse_last = motion.position
		get_viewport().set_input_as_handled()


func _emit_cell_at(viewport_position: Vector2) -> void:
	var coordinates: Vector2i = get_cell_at_viewport_position(viewport_position)
	if _snapshot == null or not _snapshot.is_in_bounds(coordinates):
		return
	if debug_clicks:
		print("FieldWorldView: cell_clicked (%d, %d)" % [coordinates.x, coordinates.y])
	cell_clicked.emit(coordinates)


## Presenter supplies eligibility from Logic. Changing modes cancels the gesture;
## refreshing eligibility while the farmer works must not cancel an active drag.
func configure_tool(active: bool, multi_select: bool, eligible: Dictionary[Vector2i, int], mode_changed: bool = false) -> void:
	if mode_changed:
		_reset_touch_gesture()
	_tool_active = active
	_multi_select = multi_select
	_eligible = eligible.duplicate()
	if selection_overlay != null:
		selection_overlay.eligible = _eligible.keys()


func show_queued(coordinates: Array[Vector2i], pending_source: Vector2i = Vector2i(-1, -1)) -> void:
	if selection_overlay != null:
		selection_overlay.queued = coordinates.duplicate()
		if pending_source.x >= 0 and not selection_overlay.queued.has(pending_source):
			selection_overlay.queued.append(pending_source)


func _begin_selection(screen_position: Vector2) -> void:
	_cancel_selection()
	_selecting = true
	_selection_last = screen_position
	_select_at(screen_position)


func _extend_selection(screen_position: Vector2) -> void:
	# Sample in terrain-local pixels so fast drags do not skip narrow diamonds.
	var local_from: Vector2 = terrain_layer.get_global_transform_with_canvas().affine_inverse() * _selection_last
	var local_to: Vector2 = terrain_layer.get_global_transform_with_canvas().affine_inverse() * screen_position
	var step_size: float = maxf(1.0, float(terrain_layer.tile_set.tile_size.y) * 0.15)
	var steps: int = maxi(1, ceili(local_from.distance_to(local_to) / step_size))
	for step: int in range(1, steps + 1):
		_select_at(_selection_last.lerp(screen_position, float(step) / float(steps)))
	_selection_last = screen_position


func _select_at(screen_position: Vector2) -> void:
	var coords: Vector2i = get_cell_at_viewport_position(screen_position)
	if not _eligible.has(coords) or _selection.has(coords):
		return
	if not _multi_select and not _selection.is_empty():
		return
	var kind: int = _eligible[coords]
	if _selection_kind < 0:
		_selection_kind = kind
	if kind != _selection_kind:
		return # Shovel gesture stays removal OR digging until release.
	_selection.append(coords)
	if selection_overlay != null:
		selection_overlay.selected = _selection.duplicate()


func _commit_selection() -> void:
	var selected: Array[Vector2i] = []
	for coords: Vector2i in _selection:
		if _eligible.get(coords, -1) == _selection_kind:
			selected.append(coords)
	var kind: int = _selection_kind
	_cancel_selection()
	if selected.size() == 1:
		cell_clicked.emit(selected[0])
	elif not selected.is_empty():
		cells_selected.emit(selected, kind)


func _cancel_selection() -> void:
	_selecting = false
	_selection_kind = -1
	_selection.clear()
	if selection_overlay != null:
		selection_overlay.selected.clear()


## A point slightly beyond an orthogonal edge midpoint, never target center.
## Outside-grid offsets are allowed at boundaries; no obstacle/pathfinding model.
func standing_point(coordinates: Vector2i, from_global: Vector2) -> Vector2:
	var center: Vector2 = terrain_layer.map_to_local(coordinates)
	var best: Vector2 = Vector2.ZERO
	var best_distance: float = INF
	for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var neighbor: Vector2 = terrain_layer.map_to_local(coordinates + direction)
		var candidate: Vector2 = terrain_layer.to_global(center.lerp(neighbor, 0.6))
		var distance: float = candidate.distance_squared_to(from_global)
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best
