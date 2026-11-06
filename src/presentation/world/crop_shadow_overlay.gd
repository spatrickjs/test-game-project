class_name CropShadowOverlay
extends Node2D
## Small procedural ground shadows; reads detached crop positions only.

@export var terrain_layer: TileMapLayer
@export var shadow_radius: Vector2 = Vector2(30.0, 12.0)
@export var shadow_offset: Vector2 = Vector2(0.0, 2.0)
@export var shadow_color: Color = Color(0.04, 0.06, 0.04, 0.24)
var _occupied: Array[Vector2i] = []

func show_snapshot(snapshot: FieldGridState) -> void:
	_occupied.clear()
	if snapshot != null:
		for y: int in range(snapshot.height):
			for x: int in range(snapshot.width):
				var cell: FieldCellState = snapshot.get_cell(Vector2i(x, y))
				if cell != null and cell.has_crop:
					_occupied.append(cell.coordinates)
	queue_redraw()

func _draw() -> void:
	if terrain_layer == null:
		return
	for coords: Vector2i in _occupied:
		var center: Vector2 = terrain_layer.map_to_local(coords) + shadow_offset
		# Nested translucent ellipses soften the edge without external textures.
		for ring: int in range(3):
			var radius: Vector2 = shadow_radius * (1.0 - float(ring) * 0.2)
			var points: PackedVector2Array = PackedVector2Array()
			for segment: int in range(40):
				var angle: float = TAU * float(segment) / 40.0
				var point: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius
				points.append(to_local(terrain_layer.to_global(point)))
			var tint: Color = shadow_color
			tint.a *= 0.25 + float(ring) * 0.15
			draw_colored_polygon(points, tint)
