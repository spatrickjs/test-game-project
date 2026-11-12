extends Control
## Smooth visual fill while ProgressBar.value retains the current snapshot value.

var bar: ProgressBar
var fill_color: Color
var _fraction: float = 0.0
var _style: StyleBoxFlat


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_style = StyleBoxFlat.new()
	_style.bg_color = fill_color
	_style.border_color = fill_color.lightened(0.2)
	_style.border_width_top = 1
	visibility_changed.connect(_reset_hidden)


func _reset_hidden() -> void:
	if not is_visible_in_tree():
		_fraction = 0.0


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	var target: float = clampf(bar.ratio, 0.0, 1.0)
	var updated: float = move_toward(_fraction, target, delta * 3.0)
	if updated != _fraction:
		_fraction = updated
		queue_redraw()


func _draw() -> void:
	if _style == null or _fraction <= 0.0:
		return
	var fill_size: Vector2 = Vector2(maxf(0.0, size.x - 4.0) * _fraction, maxf(0.0, size.y - 4.0))
	_style.set_corner_radius_all(int(minf(5.0, fill_size.x * 0.5)))
	draw_style_box(_style, Rect2(Vector2(2, 2), fill_size))
