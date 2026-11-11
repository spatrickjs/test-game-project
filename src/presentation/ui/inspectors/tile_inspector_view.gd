class_name TileInspectorView
extends PanelContainer
## Read-only snapshot display. No simulation references are retained or mutated.

signal close_requested
signal seed_infection_requested

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
	title_label.text = "Tile (%d, %d)" % [cell_state.coordinates.x, cell_state.coordinates.y]
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
		if cell_state.has_infected_debris:
			disease_label.text = "Infected debris"
	else:
		_show_crop(cell_state, crop_data)
		if cell_state.has_infected_debris:
			disease_label.text += "\nInfected debris"
	show()


func clear_display() -> void:
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
	_display_fraction(susceptible_label, susceptible_bar, "S", cell.susceptible_fraction)
	_display_fraction(exposed_label, exposed_bar, "E", cell.exposed_fraction)
	_display_fraction(infected_label, infected_bar, "I", cell.infected_fraction)
	_display_fraction(immune_label, immune_bar, "R immune", cell.recovered_immune_fraction)
	_display_fraction(dead_label, dead_bar, "R dead", cell.dead_fraction)
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


func _on_close_pressed() -> void:
	clear_display()
	close_requested.emit()


func set_seed_available(available: bool) -> void:
	if seed_infection_button != null:
		seed_infection_button.disabled = not available


func _on_seed_pressed() -> void:
	seed_infection_requested.emit()
