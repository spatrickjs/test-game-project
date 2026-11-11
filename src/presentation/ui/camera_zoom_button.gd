extends Button
## Standalone camera/harvest actions adapt their insets; existing HUD layout stays authored.

var _authored_offsets: Vector4 = Vector4.ZERO

func _ready() -> void:
	_authored_offsets = Vector4(offset_left, offset_top, offset_right, offset_bottom)
	get_viewport().size_changed.connect(_apply_safe_area)
	_apply_safe_area()

func _apply_safe_area() -> void:
	if get_parent() is Control:
		return
	var inset: Vector2 = bottom_right_safe_inset(get_viewport_rect().size)
	offset_left = _authored_offsets.x - inset.x
	offset_right = _authored_offsets.z - inset.x
	offset_top = _authored_offsets.y - inset.y
	offset_bottom = _authored_offsets.w - inset.y


static func bottom_right_safe_inset(viewport_size: Vector2) -> Vector2:
	if OS.get_name() != "Android":
		return Vector2.ZERO
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	var window_size: Vector2i = DisplayServer.window_get_size()
	if safe.size.x <= 0 or safe.size.y <= 0 or window_size.x <= 0 or window_size.y <= 0:
		return Vector2.ZERO
	var inset: Vector2 = Vector2(window_size - safe.end).max(Vector2.ZERO)
	return inset * viewport_size / Vector2(window_size)
