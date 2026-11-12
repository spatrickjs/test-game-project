extends RefCounted


static func apply(view: Control, bars: Array[ProgressBar]) -> void:
	var theme := Theme.new()
	theme.default_font_size = 15
	theme.set_color("font_color", "Label", Color("49372a"))
	theme.set_constant("separation", "VBoxContainer", 8)
	theme.set_constant("v_separation", "GridContainer", 7)
	theme.set_constant("h_separation", "HBoxContainer", 12)
	var card := box(Color("fbf3df"), Color("b48a4c"), 16)
	card.shadow_color = Color(0.12, 0.08, 0.03, 0.3)
	card.shadow_size = 10
	card.shadow_offset = Vector2(0, 5)
	theme.set_stylebox("panel", "PanelContainer", card)
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var color := Color("eee0bd")
		if state == "hover":
			color = Color("e4cd96")
		elif state == "pressed":
			color = Color("d4b478")
		theme.set_stylebox(state, "Button", box(color, Color("b48a4c"), 10))
		theme.set_color("font_color" if state == "normal" else "font_%s_color" % state, "Button", Color("49372a"))
	var line := StyleBoxLine.new()
	line.color = Color("ddcba6")
	line.thickness = 1
	theme.set_stylebox("separator", "HSeparator", line)
	var scroll_track := box(Color("eee2ca"), Color("eee2ca"), 4)
	scroll_track.content_margin_left = 4
	scroll_track.content_margin_right = 4
	theme.set_stylebox("scroll", "VScrollBar", scroll_track)
	for state: String in ["grabber", "grabber_highlight", "grabber_pressed"]:
		theme.set_stylebox(state, "VScrollBar", box(Color("b48a4c"), Color("b48a4c"), 4))
	view.theme = theme
	_style_children(view)
	var colors: Array[Color] = [Color("75934e"), Color("7096a0"), Color("d6a348"), Color("bd6251"), Color("648d74"), Color("8d8178")]
	for index: int in range(bars.size()):
		var bar: ProgressBar = bars[index]
		if bar == null:
			continue
		bar.custom_minimum_size = Vector2(0, 16)
		bar.show_percentage = false
		bar.add_theme_stylebox_override("background", box(Color("e7dcc5"), Color("d3c3a3"), 7))
		bar.add_theme_stylebox_override("fill", StyleBoxEmpty.new())
		var fill := Control.new()
		fill.set_script(preload("res://src/presentation/ui/inspectors/inspector_bar_fill.gd"))
		fill.set("bar", bar)
		fill.set("fill_color", colors[index])
		bar.add_child(fill)


static func _style_children(node: Node) -> void:
	for child in node.get_children():
		if child is MarginContainer:
			for side: String in ["left", "right", "top", "bottom"]:
				child.add_theme_constant_override("margin_" + side, 16)
		if child is Label:
			child.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			if str(child.name).ends_with("Heading"):
				child.add_theme_color_override("font_color", Color("62734a"))
				child.add_theme_font_size_override("font_size", 14)
		if child is GridContainer:
			child.columns = 1
		_style_children(child)


static func box(color: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	return style
