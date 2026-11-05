extends Button
## Only the new camera action adapts its insets; existing HUD layout stays authored.

var _authored_offsets: Vector4 = Vector4.ZERO

func _ready() -> void:
	_authored_offsets = Vector4(offset_left, offset_top, offset_right, offset_bottom)
	get_viewport().size_changed.connect(_apply_safe_area)
	_apply_safe_area()

func _apply_safe_area() -> void:
	if OS.get_name() != "Android":
		return
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	var window_size: Vector2i = DisplayServer.window_get_size()
	if safe.size.x <= 0 or safe.size.y <= 0 or window_size.x <= 0 or window_size.y <= 0:
		return
	var scale_factor: Vector2 = get_viewport_rect().size / Vector2(window_size)
	var right_inset: float = maxf(0.0, float(window_size.x - safe.end.x)) * scale_factor.x
	var bottom_inset: float = maxf(0.0, float(window_size.y - safe.end.y)) * scale_factor.y
	offset_left = _authored_offsets.x - right_inset
	offset_right = _authored_offsets.z - right_inset
	offset_top = _authored_offsets.y - bottom_inset
	offset_bottom = _authored_offsets.w - bottom_inset
