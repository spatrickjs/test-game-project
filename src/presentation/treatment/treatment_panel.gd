class_name TreatmentPanel
extends Control
## HUD panel for treatment selection, cooldown display, queue slots, and resistance bars.
## Created programmatically and wired to a TreatmentController by the presenter.

signal treatment_selected(treatment_id: StringName)

var _treatment_controller: TreatmentController = null
var _farming_controller: FarmingController = null
var _container: VBoxContainer = null
var _treatment_buttons: Dictionary = {}  # treatment_id -> Button
var _cooldown_labels: Dictionary = {}    # treatment_id -> Label
var _resistance_bars: Dictionary = {}     # group (int) -> ProgressBar
var _queue_label: Label = null
var _effects_label: Label = null
var _turn: int = 0


func setup(tc: TreatmentController, fc: FarmingController) -> void:
	_treatment_controller = tc
	_farming_controller = fc
	_build_ui()


func _build_ui() -> void:
	if _container != null:
		return
	_container = VBoxContainer.new()
	_container.add_theme_constant_override("separation", 4)
	add_child(_container)
	var title := Label.new()
	title.text = "Treatments"
	title.add_theme_font_size_override("font_size", 14)
	_container.add_child(title)
	_queue_label = Label.new()
	_container.add_child(_queue_label)
	if _treatment_controller == null or _treatment_controller.treatment_config == null:
		return
	for t: TreatmentData in _treatment_controller.treatment_config.treatments:
		if t == null:
			continue
		var row := HBoxContainer.new()
		_container.add_child(row)
		var btn := Button.new()
		btn.text = t.display_name
		btn.custom_minimum_size = Vector2(120, 0)
		btn.toggle_mode = true
		var tid: StringName = t.treatment_id
		btn.pressed.connect(func() -> void: _on_treatment_pressed(tid))
		_treatment_buttons[t.treatment_id] = btn
		row.add_child(btn)
		var cd_label := Label.new()
		cd_label.custom_minimum_size = Vector2(60, 0)
		_cooldown_labels[t.treatment_id] = cd_label
		row.add_child(cd_label)
	# Resistance bars per group
	var groups: Array[int] = [TreatmentData.ResistanceGroup.FUNGICIDE, TreatmentData.ResistanceGroup.BACTERICIDE]
	for group: int in groups:
		var bar_row := HBoxContainer.new()
		_container.add_child(bar_row)
		var gname := Label.new()
		gname.text = "%s resistance" % _group_name(group)
		gname.custom_minimum_size = Vector2(120, 0)
		bar_row.add_child(gname)
		var bar := ProgressBar.new()
		bar.min_value = 0.0
		bar.max_value = 1.0
		bar.custom_minimum_size = Vector2(100, 0)
		_resistance_bars[group] = bar
		bar_row.add_child(bar)
	_effects_label = Label.new()
	_effects_label.text = "No active effects"
	_container.add_child(_effects_label)


func _group_name(group: int) -> String:
	match group:
		TreatmentData.ResistanceGroup.FUNGICIDE:
			return "Fungicide"
		TreatmentData.ResistanceGroup.BACTERICIDE:
			return "Bactericide"
	return "Unknown"


func _on_treatment_pressed(treatment_id: StringName) -> void:
	# Toggle: deselect if already selected
	for tid in _treatment_buttons:
		var btn: Button = _treatment_buttons[tid]
		btn.set_pressed_no_signal(tid == treatment_id and not btn.button_pressed)
	treatment_selected.emit(treatment_id)


## Refreshes the panel display from the controller state.
func refresh(turn: int) -> void:
	_turn = turn
	if _treatment_controller == null or _treatment_controller.treatment_config == null:
		return
	# Queue slots
	if _farming_controller != null:
		var queued: int = _farming_controller.count_queued_treatments()
		var max_q: int = _treatment_controller.treatment_config.max_queued_per_turn
		_queue_label.text = "Queue: %d / %d" % [queued, max_q]
	# Cooldowns and button state
	for t: TreatmentData in _treatment_controller.treatment_config.treatments:
		if t == null:
			continue
		var cd: int = _treatment_controller.get_cooldown(t.treatment_id)
		var cd_label: Label = _cooldown_labels.get(t.treatment_id, null)
		if cd_label != null:
			cd_label.text = "CD: %d" % cd if cd > 0 else "Ready"
		var btn: Button = _treatment_buttons.get(t.treatment_id, null)
		if btn != null:
			btn.disabled = cd > 0
	# Resistance bars
	for group in _resistance_bars:
		var potency: float = _treatment_controller.get_resistance_potency(group, turn)
		var bar: ProgressBar = _resistance_bars[group]
		# Display resistance as (1 - potency) so full bar = maximum resistance
		bar.value = 1.0 - potency
	# Active effects summary
	var effect_count: int = _treatment_controller.treatment_state.effects.size()
	if effect_count == 0:
		_effects_label.text = "No active effects"
	else:
		var lines: Array[String] = []
		for key: String in _treatment_controller.treatment_state.effects:
			var e: TreatmentEffect = _treatment_controller.treatment_state.effects[key]
			if e != null:
				lines.append("%s (%d,%d) %dt" % [String(e.treatment_id), e.cell.x, e.cell.y, e.remaining_turns])
		_effects_label.text = ", ".join(lines)


## Returns the currently selected treatment_id, or empty if none.
func get_selected_treatment() -> StringName:
	for tid in _treatment_buttons:
		var btn: Button = _treatment_buttons[tid]
		if btn.button_pressed:
			return tid as StringName
	return &""
