extends SceneTree
## UI snapshot tests for the TreatmentPanel (Task 17).
## Tests panel states (idle, on cooldown, queue full) and effect badge display.
## These are logic-level tests that verify display values, not pixel snapshots.

var failures: int = 0


func _initialize() -> void:
	_panel_idle_state()
	_panel_cooldown_state()
	_panel_queue_full()
	_panel_resistance_bars()
	_panel_effect_badges()
	_panel_treatment_selection()
	if failures == 0:
		print("TREATMENT_PANEL_PASS")
	quit(0 if failures == 0 else 1)


func _make_tc() -> TreatmentController:
	var tc: TreatmentController = TreatmentController.new()
	tc.treatment_config = load("res://src/data/treatments/treatment_config.tres") as TreatmentConfig
	tc.disease_database = load("res://src/data/databases/default_disease_database.tres") as DiseaseDatabase
	tc.treatment_state = TreatmentState.new()
	return tc


func _make_grid() -> FieldGridState:
	var grid: FieldGridState = FieldGridState.new()
	grid.initialize(5, 5, AbioticState.new())
	for y: int in range(5):
		for x: int in range(5):
			var cell: FieldCellState = grid.get_cell(Vector2i(x, y))
			cell.terrain_type = SimulationEnums.TerrainType.DRY_SOIL
			cell.soil = SoilState.new()
			cell.has_crop = true
			cell.crop_type = SimulationEnums.CropType.RICE
			cell.reset_crop_state()
	return grid


# Panel idle state: all treatments ready, no effects
func _panel_idle_state() -> void:
	var tc: TreatmentController = _make_tc()
	var panel: TreatmentPanel = TreatmentPanel.new()
	panel.setup(tc, null)
	panel.refresh(0)
	# All treatment buttons should be enabled (no cooldowns)
	for t: TreatmentData in tc.treatment_config.treatments:
		if t == null:
			continue
		var btn: Button = panel._treatment_buttons.get(t.treatment_id, null)
		if btn == null:
			fail("Idle: button should exist for %s" % String(t.treatment_id))
			continue
		if btn.disabled:
			fail("Idle: %s button should be enabled" % String(t.treatment_id))
	# Queue label should show 0 / max
	if not panel._queue_label.text.contains("0"):
		fail("Idle: queue label should show 0 queued, got: %s" % panel._queue_label.text)
	# Effects label should say no effects
	if not panel._effects_label.text.contains("No active"):
		fail("Idle: effects label should say no effects, got: %s" % panel._effects_label.text)


# Panel on cooldown: treatment button disabled
func _panel_cooldown_state() -> void:
	var tc: TreatmentController = _make_tc()
	tc.treatment_state.set_cooldown(&"fungicide", 3)
	var panel: TreatmentPanel = TreatmentPanel.new()
	panel.setup(tc, null)
	panel.refresh(0)
	var btn: Button = panel._treatment_buttons.get(&"fungicide", null)
	if btn == null:
		fail("Cooldown: button should exist")
		return
	if not btn.disabled:
		fail("Cooldown: fungicide button should be disabled")
	var cd_label: Label = panel._cooldown_labels.get(&"fungicide", null)
	if cd_label == null:
		fail("Cooldown: label should exist")
		return
	if not cd_label.text.contains("3"):
		fail("Cooldown: label should show 3 turns, got: %s" % cd_label.text)


# Panel queue full
func _panel_queue_full() -> void:
	var tc: TreatmentController = _make_tc()
	var panel: TreatmentPanel = TreatmentPanel.new()
	# Simulate farming controller with queued treatments
	var fc: FarmingController = FarmingController.new()
	fc.treatment_controller = tc
	panel.setup(tc, fc)
	# Manually queue treatment actions to fill the queue
	for i: int in range(tc.treatment_config.max_queued_per_turn):
		var a: FieldAction = FieldAction.new()
		a.kind = SimulationEnums.FieldActionKind.APPLY_FUNGICIDE
		a.id = i + 1
		fc._actions.append(a)
	panel.refresh(0)
	# Queue label should show full
	var max_q: int = tc.treatment_config.max_queued_per_turn
	if not panel._queue_label.text.contains(str(max_q)):
		fail("Queue full: label should show %d queued, got: %s" % [max_q, panel._queue_label.text])


# Panel resistance bars
func _panel_resistance_bars() -> void:
	var tc: TreatmentController = _make_tc()
	# Build up fungicide resistance
	var grid: FieldGridState = _make_grid()
	var cell: FieldCellState = grid.get_cell(Vector2i(2, 2))
	cell.has_active_disease = true
	cell.active_disease_id = SimulationEnums.DiseaseId.RICE_BLAST
	cell.sir_state = SimulationEnums.SIRState.I
	cell.infected_fraction = 0.2
	cell.susceptible_fraction = 0.8
	for i: int in range(4):
		tc.treatment_state.set_cooldown(&"fungicide", 0)
		var a: FieldAction = FieldAction.new()
		a.kind = SimulationEnums.FieldActionKind.APPLY_FUNGICIDE
		a.target = Vector2i(2, 2)
		tc.commit_treatment(a, grid, i)
	var panel: TreatmentPanel = TreatmentPanel.new()
	panel.setup(tc, null)
	panel.refresh(3)
	# Fungicide resistance bar should be > 0
	var bar: ProgressBar = panel._resistance_bars.get(TreatmentData.ResistanceGroup.FUNGICIDE, null)
	if bar == null:
		fail("Resistance: bar should exist for FUNGICIDE group")
		return
	if bar.value <= 0.0:
		fail("Resistance: bar should be > 0 after overuse, got %f" % bar.value)
	# Bactericide resistance bar should be 0 (no usage)
	var bbar: ProgressBar = panel._resistance_bars.get(TreatmentData.ResistanceGroup.BACTERICIDE, null)
	if bbar != null and bbar.value > 0.001:
		fail("Resistance: bactericide bar should be 0, got %f" % bbar.value)


# Panel effect badges with remaining turns
func _panel_effect_badges() -> void:
	var tc: TreatmentController = _make_tc()
	# Add an effect
	var e: TreatmentEffect = TreatmentEffect.new()
	e.treatment_id = &"fungicide"
	e.cell = Vector2i(2, 3)
	e.remaining_turns = 3
	e.potency = 1.0
	tc.treatment_state.put_effect(e)
	var panel: TreatmentPanel = TreatmentPanel.new()
	panel.setup(tc, null)
	panel.refresh(0)
	# Effects label should mention the effect
	if not panel._effects_label.text.contains("fungicide"):
		fail("Badges: effects label should mention fungicide, got: %s" % panel._effects_label.text)
	if not panel._effects_label.text.contains("3"):
		fail("Badges: effects label should show 3 turns remaining, got: %s" % panel._effects_label.text)
	# After advancing 1 turn
	tc.advance_turn(1)
	panel.refresh(1)
	# Should show 2 remaining
	if not panel._effects_label.text.contains("2"):
		fail("Badges: effects label should show 2 remaining after advance, got: %s" % panel._effects_label.text)


# Panel treatment selection
func _panel_treatment_selection() -> void:
	var tc: TreatmentController = _make_tc()
	var panel: TreatmentPanel = TreatmentPanel.new()
	panel.setup(tc, null)
	# Select fungicide
	var btn: Button = panel._treatment_buttons.get(&"fungicide", null)
	if btn == null:
		fail("Selection: button should exist")
		return
	btn.set_pressed_no_signal(true)
	var selected: StringName = panel.get_selected_treatment()
	if selected != &"fungicide":
		fail("Selection: should return fungicide, got %s" % String(selected))


func fail(message: String) -> void:
	failures += 1
	printerr("FAIL: " + message)
