class_name CropDebugOverlay
extends Node2D
## Draws detached snapshots only. No runtime crop state is mutated here.

@export var terrain_layer: TileMapLayer
@export var label_font: Font
@export_range(8, 64, 1) var font_size: int = 18
@export var growing_color: Color = Color(0.2, 0.65, 0.3, 0.95)
@export var mature_color: Color = Color(1.0, 0.75, 0.15, 0.95)
@export var text_color: Color = Color.WHITE
@export var marker_radius: float = 22.0
## Relative to Terrain's Z index. Both nodes should be siblings under World.
@export_range(1, 100, 1) var terrain_z_offset: int = 1

var _snapshot: FieldGridState = null
var _crops: CropDatabase = null
var _reported_errors: PackedStringArray = PackedStringArray()


func _ready() -> void:
	_configure_draw_order()
	queue_redraw()


func show_snapshot(snapshot: FieldGridState, crops: CropDatabase) -> void:
	_snapshot = snapshot
	_crops = crops
	_configure_draw_order()
	if terrain_layer == null:
		_report_once("CropDebugOverlay: assign terrain_layer in the Inspector.")
	if snapshot == null:
		_report_once("CropDebugOverlay: no field snapshot was supplied.")
	if crops == null:
		_report_once("CropDebugOverlay: no crop catalog was supplied.")
	queue_redraw()


func _configure_draw_order() -> void:
	# One Node2D draws all markers at its own sort position. It must not
	# compete with individual Y-sorted terrain cells at the same Z index.
	y_sort_enabled = false
	show_behind_parent = false
	z_as_relative = true
	if terrain_layer != null:
		if get_parent() != terrain_layer.get_parent():
			_report_once("CropDebugOverlay and Terrain must be siblings under World.")
		z_index = clampi(terrain_layer.z_index + terrain_z_offset, -4096, 4096)


func get_cell_draw_position(coordinates: Vector2i) -> Vector2:
	# Terrain-local cell center -> canvas position -> overlay-local position.
	# This preserves the isometric layout and both nodes' transforms.
	if terrain_layer == null:
		return Vector2.ZERO
	return (
		get_global_transform_with_canvas().affine_inverse()
		* terrain_layer.get_global_transform_with_canvas()
		* terrain_layer.map_to_local(coordinates)
	)


func _draw() -> void:
	if _snapshot == null or _crops == null or terrain_layer == null:
		return
	var font: Font = label_font
	if font == null or font.get_height(font_size) <= 0.0:
		font = ThemeDB.fallback_font
	if font == null:
		_report_once("CropDebugOverlay: no font is available; assign label_font. Markers still render.")
	for y: int in range(_snapshot.height):
		for x: int in range(_snapshot.width):
			var cell: FieldCellState = _snapshot.get_cell(Vector2i(x, y))
			if cell == null or not cell.has_crop:
				continue
			var crop: CropData = _crops.get_crop(cell.crop_type)
			if crop == null:
				_report_once("CropDebugOverlay: crop_type %d is missing from the catalog." % cell.crop_type)
			var center: Vector2 = get_cell_draw_position(cell.coordinates)
			var tint: Color = mature_color if cell.is_mature(crop) else growing_color
			var radius: float = maxf(1.0, marker_radius)
			draw_circle(center, radius, tint)
			if cell.is_inoculated():
				draw_arc(center, radius + 6.0, 0.0, TAU, 32, Color(0.35, 0.95, 1.0, 0.85), 3.0, true)
			var abbreviation: String = _abbreviation(cell.crop_type)
			if font != null:
				var text_size: Vector2 = font.get_string_size(
					abbreviation, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size
				)
				var baseline: Vector2 = center + Vector2(
					-text_size.x * 0.5,
					(font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
				)
				draw_string(
					font, baseline, abbreviation,
					HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color
				)
			var progress: float = 0.0
			if crop != null:
				progress = clampf(
					float(cell.growth_elapsed_ticks) / float(maxi(1, crop.growth_ticks)), 0.0, 1.0
				)
			var bar: Rect2 = Rect2(center + Vector2(-radius, radius + 3.0), Vector2(radius * 2.0, 5.0))
			draw_rect(bar, Color(0.1, 0.1, 0.1, 0.9))
			bar.size.x *= progress
			draw_rect(bar, tint)


func _report_once(message: String) -> void:
	if not _reported_errors.has(message):
		_reported_errors.append(message)
		push_warning(message)


func _abbreviation(crop_type: SimulationEnums.CropType) -> String:
	match crop_type:
		SimulationEnums.CropType.SUGARCANE:
			return "SC"
		SimulationEnums.CropType.RICE:
			return "RI"
		SimulationEnums.CropType.CORN:
			return "CO"
	return "?"
