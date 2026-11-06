class_name FieldSelectionOverlay
extends Node2D
## Only logical coordinates and terrain transforms; no gameplay decisions.

@export var terrain_layer: TileMapLayer
var eligible: Array[Vector2i] = []
var selected: Array[Vector2i] = []
var queued: Array[Vector2i] = []
var _phase: float = 0.0

func _process(delta: float) -> void:
	_phase = fmod(_phase + delta * 5.0, TAU)
	queue_redraw()

func diamond(coordinates: Vector2i) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	if terrain_layer == null or terrain_layer.tile_set == null:
		return points
	var center: Vector2 = terrain_layer.map_to_local(coordinates)
	var half_size: Vector2 = Vector2(terrain_layer.tile_set.tile_size) * 0.5
	for offset: Vector2 in [Vector2(0, -half_size.y), Vector2(half_size.x, 0), Vector2(0, half_size.y), Vector2(-half_size.x, 0)]:
		points.append(to_local(terrain_layer.to_global(center + offset)))
	return points

func _draw() -> void:
	for coords: Vector2i in eligible:
		_draw_diamond(coords, Color(0.65, 1.0, 0.72, 0.1), Color(0.65, 1.0, 0.72, 0.65))
	var pulse: float = 0.25 + 0.25 * (sin(_phase) + 1.0)
	for coords: Vector2i in queued:
		_draw_diamond(coords, Color(1.0, 0.75, 0.15, pulse * 0.5), Color(1.0, 0.8, 0.25, pulse))
	for coords: Vector2i in selected:
		_draw_diamond(coords, Color(0.4, 0.9, 1.0, pulse * 0.5), Color(0.5, 0.95, 1.0, pulse))

func _draw_diamond(coords: Vector2i, fill: Color, outline: Color) -> void:
	var points: PackedVector2Array = diamond(coords)
	if points.is_empty():
		return
	draw_colored_polygon(points, fill)
	points.append(points[0])
	draw_polyline(points, outline, 3.0, true)
