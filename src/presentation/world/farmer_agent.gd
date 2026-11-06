class_name FarmerAgent
extends Node2D
## Visual locomotion only. Arrival is an intent; Logic owns the task and mutation.

signal arrived(action_id: int, coordinates: Vector2i)
@export_range(1.0, 2000.0) var walk_speed: float = 360.0
var _action_id: int = -1
var _stop: Vector2i = Vector2i(-1, -1)
var _destination: Vector2 = Vector2.ZERO
var _walking: bool = false

func walk_to(action_id: int, coordinates: Vector2i, destination: Vector2) -> void:
	if _walking and action_id == _action_id and coordinates == _stop:
		return
	_action_id = action_id
	_stop = coordinates
	_destination = destination
	_walking = true

func stop() -> void:
	_walking = false
	_action_id = -1

func _process(delta: float) -> void:
	if not _walking or not is_finite(walk_speed) or walk_speed <= 0.0:
		return
	global_position = global_position.move_toward(_destination, walk_speed * delta)
	if global_position.is_equal_approx(_destination):
		_walking = false
		# A listener may immediately schedule the next stop. Keep this emission's
		# arguments stable for every listener, even under synchronous re-entry.
		var completed_id: int = _action_id
		var completed_stop: Vector2i = _stop
		arrived.emit(completed_id, completed_stop)

func _draw() -> void:
	# Feet are at the node origin, which also provides the depth-sort position.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.48))
	draw_circle(Vector2.ZERO, 19.0, Color(0.05, 0.12, 0.1, 0.45))
	draw_arc(Vector2.ZERO, 19.0, 0.0, TAU, 32, Color(0.85, 1.0, 0.8), 2.0, true)
	draw_set_transform(Vector2.ZERO)
	draw_line(Vector2(-7, -3), Vector2(-6, -20), Color(0.15, 0.2, 0.3), 7.0, true)
	draw_line(Vector2(7, -3), Vector2(6, -20), Color(0.15, 0.2, 0.3), 7.0, true)
	draw_style_box(_body_style(), Rect2(-14, -47, 28, 29))
	draw_circle(Vector2(0, -57), 12.0, Color(0.95, 0.72, 0.47))
	draw_line(Vector2(-19, -65), Vector2(19, -65), Color(0.96, 0.8, 0.35), 7.0, true)
	draw_rect(Rect2(-10, -76, 20, 11), Color(0.96, 0.8, 0.35))

func _body_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.52, 0.64)
	style.set_corner_radius_all(6)
	return style
