class_name TileInspectorView
extends PanelContainer
## Read-only snapshot display. No simulation references are retained or mutated.

signal close_requested
signal seed_infection_requested

@export_group("Popup")
@export_range(240.0, 480.0, 1.0) var popup_width: float = 300.0
@export_range(280.0, 640.0, 1.0) var popup_height: float = 500.0
@export_range(8.0, 48.0, 1.0) var screen_margin: float = 16.0
@export_range(8.0, 64.0, 1.0) var tile_gap: float = 16.0
@export_range(0.0, 0.5, 0.01) var opening_duration: float = 0.15

var _opening_tween: Tween
var _opening_offset: float = 0.0
var _pointer_side: int = 0
var _pointer_y: float = 0.0
var _displayed_coordinates: Vector2i = Vector2i(-1, -1)

@export_group("Catalog")
## Optional during authoring; an unresolved active ID is displayed explicitly.
@export var disease_database: DiseaseDatabase

@export_group("Structure")
@export var close_button: Button
@export var seed_infection_button: Button
@export var scroll_container: ScrollContainer
@export_group("Labels")
@export var title_label: Label
@export var terrain_label: Label
@export var soil_ph_label: Label
@export var macronutrients_label: Label
@export var crop_name_label: Label
@export var growth_label: Label
@export var disease_label: Label
@export var state_label: Label
@export var removed_outcome_label: Label
@export var susceptible_label: Label
@export var exposed_label: Label
@export var infected_label: Label
@export var immune_label: Label
@export var dead_label: Label

@export_group("Progress Bars")
@export var growth_bar: ProgressBar
@export var susceptible_bar: ProgressBar
@export var exposed_bar: ProgressBar
@export var infected_bar: ProgressBar
@export var immune_bar: ProgressBar
@export var dead_bar: ProgressBar


func _ready() -> void:
	preload("res://src/presentation/ui/inspectors/inspector_theme.gd").apply(self, _bars())
	if title_label != null:
		title_label.add_theme_font_size_override("font_size", 20)
	if close_button != null:
		close_button.text = "×"
		close_button.tooltip_text = "Close inspector"
		close_button.custom_minimum_size = Vector2(44, 44)
	if scroll_container != null:
		scroll_container.custom_minimum_size = Vector2(0, 80)
		scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	if seed_infection_button != null and not seed_infection_button.pressed.is_connected(_on_seed_pressed):
		seed_infection_button.pressed.connect(_on_seed_pressed)
	if close_button != null and not close_button.pressed.is_connected(_on_close_pressed):
		close_button.pressed.connect(_on_close_pressed)
	clear_display()


func validate_configuration() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if close_button == null:
		errors.append("TileInspector: assign close_button.")
	if scroll_container == null:
		errors.append("TileInspector: assign scroll_container.")
	if title_label == null:
		errors.append("TileInspector: assign title_label.")
	if terrain_label == null:
		errors.append("TileInspector: assign terrain_label.")
	if soil_ph_label == null:
		errors.append("TileInspector: assign soil_ph_label.")
	if macronutrients_label == null:
		errors.append("TileInspector: assign macronutrients_label.")
	if crop_name_label == null:
		errors.append("TileInspector: assign crop_name_label.")
	if growth_label == null:
		errors.append("TileInspector: assign growth_label.")
	if disease_label == null:
		errors.append("TileInspector: assign disease_label.")
	if state_label == null:
		errors.append("TileInspector: assign state_label.")
	if removed_outcome_label == null:
		errors.append("TileInspector: assign removed_outcome_label.")
	if susceptible_label == null:
		errors.append("TileInspector: assign susceptible_label.")
	if exposed_label == null:
		errors.append("TileInspector: assign exposed_label.")
	if infected_label == null:
		errors.append("TileInspector: assign infected_label.")
	if immune_label == null:
		errors.append("TileInspector: assign immune_label.")
	if dead_label == null:
		errors.append("TileInspector: assign dead_label.")
	if growth_bar == null:
		errors.append("TileInspector: assign growth_bar.")
	if susceptible_bar == null:
		errors.append("TileInspector: assign susceptible_bar.")
	if exposed_bar == null:
		errors.append("TileInspector: assign exposed_bar.")
	if infected_bar == null:
		errors.append("TileInspector: assign infected_bar.")
	if immune_bar == null:
		errors.append("TileInspector: assign immune_bar.")
	if dead_bar == null:
		errors.append("TileInspector: assign dead_bar.")
	return errors


## FieldGridState is the whole field. Pass its selected FieldCellState here.
func display_cell(cell_state: FieldCellState, crop_data: CropData) -> void:
	if cell_state == null:
		clear_display()
		return
	var errors: PackedStringArray = validate_configuration()
	if not errors.is_empty():
		clear_display()
		push_error("\n".join(errors))
		return
	var opening: bool = not visible or _displayed_coordinates != cell_state.coordinates
	_displayed_coordinates = cell_state.coordinates
	title_label.text = crop_data.display_name if cell_state.has_crop and crop_data != null else _terrain_name(cell_state.terrain_type)
	title_label.tooltip_text = "Tile (%d, %d)" % [cell_state.coordinates.x, cell_state.coordinates.y]
	terrain_label.text = "Terrain: %s" % _terrain_name(cell_state.terrain_type)
	if cell_state.has_fence:
		terrain_label.text += " (fenced)"
	if cell_state.soil == null:
		soil_ph_label.text = "No soil data"
		macronutrients_label.text = "N: —   P: —   K: —"
	else:
		var soil: SoilState = cell_state.soil
		if is_nan(soil.soil_ph) or is_inf(soil.soil_ph) or soil.soil_ph < 0.0 or soil.soil_ph > 14.0:
			soil_ph_label.text = "Soil pH: INVALID (%s)" % soil.soil_ph
		else:
			soil_ph_label.text = "Soil pH: %.2f" % soil.soil_ph
		macronutrients_label.text = "Availability\nN: %s   P: %s   K: %s" % [
			_normalized_text(soil.nitrogen), _normalized_text(soil.phosphorus),
			_normalized_text(soil.potassium),
		]
		macronutrients_label.text += "\nSoil moisture: " + _normalized_text(soil.moisture)
	if not cell_state.has_crop:
		_show_empty_crop()
	else:
		_show_crop(cell_state, crop_data)
	show()
	if opening:
		scroll_container.scroll_vertical = 0
		if _opening_tween != null:
			_opening_tween.kill()
		modulate.a = 0.0
		_opening_offset = 8.0
		_opening_tween = create_tween().set_parallel(true)
		_opening_tween.tween_property(self, "modulate:a", 1.0, opening_duration)
		_opening_tween.tween_property(self, "_opening_offset", 0.0, opening_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func clear_display() -> void:
	if _opening_tween != null:
		_opening_tween.kill()
	_opening_offset = 0.0
	_displayed_coordinates = Vector2i(-1, -1)
	set_seed_available(false)
	for label: Label in _labels():
		if label != null:
			label.text = ""
	for bar: ProgressBar in _bars():
		if bar != null:
			bar.value = 0.0
			bar.hide()
	hide()


func _show_empty_crop() -> void:
	crop_name_label.text = "No crop"
	growth_label.text = "Growth: Not applicable"
	disease_label.text = "Disease: Not applicable"
	state_label.text = "Categorical state: Not applicable"
	removed_outcome_label.text = "Removed outcome: Not applicable"
	susceptible_label.text = "S: Not applicable"
	exposed_label.text = "E: Not applicable"
	infected_label.text = "I: Not applicable"
	immune_label.text = "R immune: Not applicable"
	dead_label.text = "R dead: Not applicable"
	for bar: ProgressBar in _bars():
		bar.value = 0.0
		bar.hide()


func _show_crop(cell: FieldCellState, crop: CropData) -> void:
	if crop == null or crop.crop_type != cell.crop_type:
		crop_name_label.text = "Unknown crop (ID %d)" % cell.crop_type
		growth_label.text = "Growth: %d / — ticks; crop definition unavailable" % cell.growth_elapsed_ticks
		growth_bar.hide()
	elif crop.growth_ticks < 1 or cell.growth_elapsed_ticks < 0:
		crop_name_label.text = crop.display_name
		growth_label.text = "Growth: INVALID (%d / %d ticks)" % [cell.growth_elapsed_ticks, crop.growth_ticks]
		growth_bar.hide()
	else:
		crop_name_label.text = crop.display_name
		growth_label.text = "%s — %d / %d ticks" % [
			"Mature" if cell.is_mature(crop) else "Growing",
			cell.growth_elapsed_ticks, crop.growth_ticks,
		]
		growth_bar.value = minf(100.0, 100.0 * float(cell.growth_elapsed_ticks) / float(crop.growth_ticks))
		growth_label.text += "  ·  %.1f%%" % growth_bar.value
		growth_bar.show()
	growth_label.text += "\nVitality: %s | Yield quality: %s" % [_normalized_text(cell.vitality), _normalized_text(1.0 - cell.yield_quality_loss)]
	disease_label.text = "Active disease: None"
	if cell.has_active_disease:
		var disease: DiseaseData = null
		if disease_database != null:
			disease = disease_database.get_disease(cell.active_disease_id)
		if disease == null or disease.display_name.strip_edges().is_empty():
			disease_label.text = "Active disease: Unknown disease (ID %d)" % cell.active_disease_id
		else:
			disease_label.text = "Active disease: %s" % disease.display_name
	state_label.text = "Categorical state: %s" % _state_name(cell.sir_state)
	removed_outcome_label.text = "Removed outcome: %s" % _outcome_name(cell.removed_outcome)
	_display_fraction(susceptible_label, susceptible_bar, "Susceptible", cell.susceptible_fraction)
	_display_fraction(exposed_label, exposed_bar, "Exposed", cell.exposed_fraction)
	_display_fraction(infected_label, infected_bar, "Infected", cell.infected_fraction)
	_display_fraction(immune_label, immune_bar, "Immune", cell.recovered_immune_fraction)
	_display_fraction(dead_label, dead_bar, "Dead", cell.dead_fraction)
	var total: float = (
		cell.susceptible_fraction + cell.exposed_fraction + cell.infected_fraction
		+ cell.recovered_immune_fraction + cell.dead_fraction
	)
	if is_nan(total) or is_inf(total) or absf(total - 1.0) > FieldCellState.FRACTION_SUM_TOLERANCE:
		state_label.text += "\nINVALID compartment total: %s (expected 1.0)" % total


func _display_fraction(label: Label, bar: ProgressBar, caption: String, value: float) -> void:
	label.text = "%s: %s" % [caption, _normalized_text(value)]
	if not _is_normalized(value):
		bar.value = 0.0
		bar.hide()
		return
	bar.value = value * 100.0
	bar.show()


func _is_normalized(value: float) -> bool:
	return not is_nan(value) and not is_inf(value) and value >= 0.0 and value <= 1.0


func _normalized_text(value: float) -> String:
	if not _is_normalized(value):
		return "INVALID (%s)" % value
	return "%.1f%%" % (value * 100.0)


func _terrain_name(terrain: SimulationEnums.TerrainType) -> String:
	match terrain:
		SimulationEnums.TerrainType.DRY_SOIL:
			return "Dry soil"
		SimulationEnums.TerrainType.PADDY_MUD:
			return "Paddy mud"
		SimulationEnums.TerrainType.GRASS:
			return "Grass"
	return "Unknown (ID %d)" % terrain


func _state_name(state: SimulationEnums.SIRState) -> String:
	match state:
		SimulationEnums.SIRState.S:
			return "S — Susceptible"
		SimulationEnums.SIRState.E:
			return "E — Exposed"
		SimulationEnums.SIRState.I:
			return "I — Infected"
		SimulationEnums.SIRState.R:
			return "R — Removed"
	return "INVALID (ID %d)" % state


func _outcome_name(outcome: SimulationEnums.RemovedOutcome) -> String:
	match outcome:
		SimulationEnums.RemovedOutcome.NONE:
			return "None"
		SimulationEnums.RemovedOutcome.RECOVERED_IMMUNE:
			return "Recovered / immune"
		SimulationEnums.RemovedOutcome.DEAD:
			return "Dead"
	return "INVALID (ID %d)" % outcome


func _labels() -> Array[Label]:
	return [title_label, terrain_label, soil_ph_label, macronutrients_label, crop_name_label, growth_label, disease_label, state_label, removed_outcome_label, susceptible_label, exposed_label, infected_label, immune_label, dead_label]


func _bars() -> Array[ProgressBar]:
	return [growth_bar, susceptible_bar, exposed_bar, infected_bar, immune_bar, dead_bar]


## The presenter supplies canvas coordinates and occupied HUD rectangles.
func place_near_tile(target: Vector2, obstacles: Array[Rect2], tile_half_width: float = 0.0) -> void:
	var bounds: Rect2 = get_viewport_rect()
	# Keep the card readable when the project stretches its 1280-wide canvas
	# into a smaller physical window, including portrait phone screens.
	var screen_scale: Vector2 = get_viewport().get_screen_transform().get_scale().abs()
	var ui_scale: float = 1.0 / clampf(minf(screen_scale.x, screen_scale.y), 0.25, 1.0)
	if OS.get_name() == "Android":
		var safe: Rect2i = DisplayServer.get_display_safe_area()
		var window_size: Vector2i = DisplayServer.window_get_size()
		if safe.size.x > 0 and safe.size.y > 0 and window_size.x > 0 and window_size.y > 0:
			var ratio: Vector2 = bounds.size / Vector2(window_size)
			bounds = Rect2(Vector2(safe.position) * ratio, Vector2(safe.size) * ratio)
	bounds = bounds.grow(-screen_margin * ui_scale)
	var canvas_inverse: Transform2D = get_canvas_transform().affine_inverse()
	bounds = canvas_inverse * bounds
	var chosen: Rect2 = popup_rect(target, bounds, Vector2(popup_width, popup_height) * ui_scale, tile_gap * ui_scale + tile_half_width, obstacles)
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	scale = Vector2.ONE * ui_scale
	size = chosen.size / ui_scale
	global_position = chosen.position
	_pointer_side = 0
	if bounds.has_point(target):
		if chosen.position.x >= target.x + tile_gap * ui_scale - 1.0:
			_pointer_side = -1
		elif chosen.end.x <= target.x - tile_gap * ui_scale + 1.0:
			_pointer_side = 1
	var slide: float = _opening_offset * float(-_pointer_side)
	global_position.x = clampf(global_position.x + slide, bounds.position.x, bounds.end.x - size.x * ui_scale)
	_pointer_y = clampf((target.y - global_position.y) / ui_scale, 24.0, size.y - 24.0)
	queue_redraw()


static func popup_rect(target: Vector2, bounds: Rect2, desired: Vector2, gap: float, obstacles: Array[Rect2]) -> Rect2:
	var card_size: Vector2 = desired.min(bounds.size)
	var left_room: float = target.x - gap - bounds.position.x
	var right_room: float = bounds.end.x - target.x - gap
	if maxf(left_room, right_room) < card_size.x:
		card_size = Vector2(minf(bounds.size.x, desired.x * 1.6), minf(card_size.y, maxf(desired.y * 0.36, bounds.size.y * 0.45)))
		return Rect2(Vector2(bounds.get_center().x - card_size.x * 0.5, bounds.end.y - card_size.y), card_size)
	var prefer_right: bool = target.x < bounds.get_center().x
	var best := Rect2()
	var best_score: float = INF
	for right_side: bool in [prefer_right, not prefer_right]:
		var x: float = target.x + gap if right_side else target.x - gap - card_size.x
		if x < bounds.position.x or x + card_size.x > bounds.end.x:
			continue
		var ideal_y: float = clampf(target.y - card_size.y * 0.4, bounds.position.y, bounds.end.y - card_size.y)
		for y: float in [ideal_y, bounds.position.y, bounds.end.y - card_size.y]:
			var candidate := Rect2(Vector2(x, y), card_size)
			var score: float = absf(y - ideal_y) + (0.0 if right_side == prefer_right else 100.0)
			for obstacle: Rect2 in obstacles:
				if candidate.intersects(obstacle):
					score += candidate.intersection(obstacle).get_area() * 10.0
			if score < best_score:
				best_score = score
				best = candidate
	# A panned-offscreen tile can leave both candidates outside the viewport.
	if best_score == INF:
		best = Rect2(Vector2(clampf(target.x, bounds.position.x, bounds.end.x - card_size.x), clampf(target.y, bounds.position.y, bounds.end.y - card_size.y)), card_size)
	return best


func _draw() -> void:
	if _pointer_side == 0:
		return
	var x: float = 0.0 if _pointer_side < 0 else size.x
	var points := PackedVector2Array([Vector2(x, _pointer_y - 9), Vector2(x + _pointer_side * 10, _pointer_y), Vector2(x, _pointer_y + 9)])
	draw_colored_polygon(points, Color("fbf3df"))
	draw_polyline(points, Color("b48a4c"), 1.0, true)


func _on_close_pressed() -> void:
	clear_display()
	close_requested.emit()


func set_seed_available(available: bool) -> void:
	if seed_infection_button != null:
		seed_infection_button.disabled = not available


func _on_seed_pressed() -> void:
	seed_infection_requested.emit()
