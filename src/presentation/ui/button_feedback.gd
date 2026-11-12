extends Control
## Animates drawing only, keeping the button's input rectangle stable.

@export var button: Button
@export_range(0.8, 1.0, 0.01) var press_scale: float = 0.95
@export_range(0.01, 0.5, 0.01) var animation_duration: float = 0.1
@export var selected_color: Color = Color("ffd166")
@export_range(1.0, 6.0, 0.5) var outline_thickness: float = 3.0

var _held: bool = false
var _press_amount: float = 0.0
var _selected: bool = false
var _disabled: bool = false
var _material: ShaderMaterial
var _outline: StyleBoxFlat


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	if button == null:
		set_process(false)
		return
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_material = ShaderMaterial.new()
	_material.shader = preload("res://src/presentation/ui/button_feedback.gdshader")
	button.material = _material
	_outline = StyleBoxFlat.new()
	_outline.bg_color = Color.TRANSPARENT
	_outline.set_corner_radius_all(12)
	button.button_down.connect(_on_button_down)
	button.button_up.connect(_release)
	button.mouse_exited.connect(_release)
	button.visibility_changed.connect(_release)
	button.resized.connect(_refresh_geometry)
	_refresh_geometry()


func _on_button_down() -> void:
	_held = true


func _release() -> void:
	_held = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_release()


func _refresh_geometry() -> void:
	_material.set_shader_parameter("button_center", button.size * 0.5)
	queue_redraw()


func _process(delta: float) -> void:
	if button.disabled or not button.is_visible_in_tree() or not button.can_process():
		_release()
	var target: float = 1.0 if _held else 0.0
	_press_amount = move_toward(_press_amount, target, delta / maxf(animation_duration, 0.01))
	_material.set_shader_parameter("press_amount", _press_amount)
	_material.set_shader_parameter("press_scale", press_scale)
	_material.set_shader_parameter("disabled_amount", 1.0 if button.disabled else 0.0)
	var selected: bool = button.toggle_mode and button.button_pressed
	if selected != _selected or button.disabled != _disabled:
		_selected = selected
		_disabled = button.disabled
		queue_redraw()


func _draw() -> void:
	if not _selected or _outline == null:
		return
	var color: Color = selected_color
	if _disabled:
		color.a *= 0.45
	_outline.border_color = color
	_outline.set_border_width_all(int(outline_thickness))
	draw_style_box(_outline, Rect2(Vector2.ZERO, size).grow(-2.0))
	var center: Vector2 = Vector2(size.x - 12.0, 12.0)
	draw_circle(center, 9.0, color)
	draw_polyline(PackedVector2Array([center + Vector2(-4, 0), center + Vector2(-1, 3), center + Vector2(4, -3)]), Color("332711"), 2.0, true)
