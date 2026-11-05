class_name FieldPrototypePresenter
extends Node
## Composition root: wires intents to Logic and displays detached state.
## Assign every reference below in the Inspector; no node paths are hardcoded.

@export_group("Scene Components")
@export var farming_controller: FarmingController
@export var turn_controller: TurnController
@export var world_view: FieldWorldView
@export var tile_inspector: TileInspectorView

@export_group("HUD")
@export var hud_panel: PanelContainer
@export var turn_label: Label
@export var selected_crop_label: Label
@export var status_label: Label
@export var sugarcane_button: Button
@export var rice_button: Button
@export var corn_button: Button
@export var next_turn_button: Button
@export var algorithm_selector: OptionButton
@export var remove_button: Button
@export var transfer_button: Button
@export var camera_zoom_button: Button
enum ToolMode { INSPECT, PLANT, TOOL_REMOVE, TOOL_TRANSFER }
var _tool_mode: ToolMode = ToolMode.INSPECT
var _transfer_source: Vector2i = Vector2i(-1, -1)
@export var playtest_disease_id: SimulationEnums.DiseaseId = SimulationEnums.DiseaseId.RICE_BLAST
var _selected_crop: SimulationEnums.CropType = SimulationEnums.CropType.SUGARCANE
var _running: bool = false
var _planting_enabled: bool = false
var _inspected_coordinates: Vector2i = Vector2i(-1, -1)


func _ready() -> void:
	var errors: PackedStringArray = _validate_references()
	if not errors.is_empty():
		_show_failure("\n".join(errors))
		return
	_set_controls_enabled(false)
	var crop_buttons: Array[Button] = [sugarcane_button, rice_button, corn_button]
	for button: Button in crop_buttons:
		button.toggle_mode = true
		button.button_group = null
		button.set_pressed_no_signal(false)
	for button: Button in [remove_button, transfer_button]:
		if button != null:
			button.toggle_mode = true
			button.set_pressed_no_signal(false)
	_connect_signals()
	errors = world_view.validate_configuration()
	if not errors.is_empty():
		_show_failure("\n".join(errors))
		return
	# All listeners are connected before Logic emits its initialization signal.
	if not farming_controller.initialize_field():
		_show_failure(farming_controller.last_error)


func _connect_once(source: Signal, callback: Callable) -> void:
	if not source.is_connected(callback):
		source.connect(callback)


func _connect_signals() -> void:
	world_view.register_ui_input_root(hud_panel)
	world_view.register_ui_input_root(tile_inspector)
	if camera_zoom_button != null:
		world_view.register_ui_input_root(camera_zoom_button)
		_connect_once(camera_zoom_button.pressed, world_view.toggle_inspection_zoom)
		_connect_once(world_view.camera_view_changed, _refresh_camera_button)

	if remove_button != null:
		_connect_once(remove_button.pressed, _on_remove_pressed)
	if transfer_button != null:
		_connect_once(transfer_button.pressed, _on_transfer_pressed)
	_connect_once(sugarcane_button.pressed, _on_sugarcane_pressed)
	_connect_once(rice_button.pressed, _on_rice_pressed)
	_connect_once(corn_button.pressed, _on_corn_pressed)
	_connect_once(next_turn_button.pressed, _on_next_turn_pressed)
	_connect_once(world_view.cell_clicked, _on_cell_clicked)
	_connect_once(farming_controller.field_initialized, _on_field_initialized)
	_connect_once(farming_controller.cell_changed, _on_cell_changed)
	_connect_once(farming_controller.planting_rejected, _on_planting_rejected)
	_connect_once(turn_controller.turn_completed, _on_turn_completed)
	_connect_once(get_viewport().size_changed, _on_viewport_resized)
	_connect_once(tile_inspector.close_requested, _on_inspector_closed)
	_connect_once(tile_inspector.seed_infection_requested, _on_seed_infection_requested)
	if algorithm_selector != null:
		_connect_once(algorithm_selector.item_selected, _on_algorithm_selected)


func _on_viewport_resized() -> void:
	world_view.frame_field.call_deferred()


func _validate_references() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if farming_controller == null:
		errors.append("Presenter: assign farming_controller.")
	if turn_controller == null:
		errors.append("Presenter: assign turn_controller.")
	elif turn_controller.farming_controller != farming_controller:
		errors.append("TurnController: assign the same FarmingController as Presenter.")
	if world_view == null:
		errors.append("Presenter: assign world_view.")
	if tile_inspector == null:
		errors.append("Presenter: assign tile_inspector.")
	else:
		errors.append_array(tile_inspector.validate_configuration())
	if hud_panel == null or turn_label == null or selected_crop_label == null or status_label == null:
		errors.append("Presenter: assign hud_panel and all three labels.")
	if sugarcane_button == null or rice_button == null or corn_button == null or next_turn_button == null:
		errors.append("Presenter: assign all four buttons.")
	return errors


func _on_field_initialized() -> void:
	turn_controller.reset_clock()
	var snapshot: FieldGridState = farming_controller.get_grid_snapshot()
	if not world_view.render_field(snapshot, farming_controller.crop_database):
		_show_failure(world_view.last_error)
		return
	_running = true
	_set_controls_enabled(true)
	_enter_inspect_mode()
	turn_label.text = "Turn: 0"
	_sync_algorithm_selector()
	# Run again after the scene's first layout pass.
	world_view.frame_field.call_deferred()


func _set_controls_enabled(enabled: bool) -> void:
	for button: Button in [remove_button, transfer_button]:
		if button != null:
			button.disabled = not enabled
	next_turn_button.disabled = not enabled
	var catalog: CropDatabase = farming_controller.crop_database
	sugarcane_button.disabled = not enabled or catalog == null or not catalog.has_crop(SimulationEnums.CropType.SUGARCANE)
	rice_button.disabled = not enabled or catalog == null or not catalog.has_crop(SimulationEnums.CropType.RICE)
	corn_button.disabled = not enabled or catalog == null or not catalog.has_crop(SimulationEnums.CropType.CORN)


func _select_crop(crop_type: SimulationEnums.CropType) -> void:
	if not _running:
		return
	var crop: CropData = farming_controller.crop_database.get_crop(crop_type)
	if crop == null:
		return
	if _planting_enabled and _selected_crop == crop_type:
		_enter_inspect_mode()
		return
	_planting_enabled = true
	_tool_mode = ToolMode.PLANT
	_transfer_source = Vector2i(-1, -1)
	_selected_crop = crop_type
	_inspected_coordinates = Vector2i(-1, -1)
	tile_inspector.clear_display()
	_update_crop_buttons()
	selected_crop_label.text = "Plant: %s" % crop.display_name
	status_label.text = "Click an eligible tile to plant. Click this crop button again to inspect."


func _enter_inspect_mode() -> void:
	_tool_mode = ToolMode.INSPECT
	_transfer_source = Vector2i(-1, -1)
	_planting_enabled = false
	_inspected_coordinates = Vector2i(-1, -1)
	tile_inspector.clear_display()
	_update_crop_buttons()
	selected_crop_label.text = "Mode: Inspect"
	status_label.text = "Click a tile to inspect it, or select a crop to plant."


func _update_crop_buttons() -> void:
	if remove_button != null:
		remove_button.set_pressed_no_signal(_tool_mode == ToolMode.TOOL_REMOVE)
	if transfer_button != null:
		transfer_button.set_pressed_no_signal(_tool_mode == ToolMode.TOOL_TRANSFER)
	sugarcane_button.set_pressed_no_signal(_planting_enabled and _selected_crop == SimulationEnums.CropType.SUGARCANE)
	rice_button.set_pressed_no_signal(_planting_enabled and _selected_crop == SimulationEnums.CropType.RICE)
	corn_button.set_pressed_no_signal(_planting_enabled and _selected_crop == SimulationEnums.CropType.CORN)


func _refresh_inspected_cell() -> void:
	if _planting_enabled or _inspected_coordinates.x < 0:
		return
	var snapshot: FieldGridState = farming_controller.get_grid_snapshot()
	if snapshot == null:
		_on_inspector_closed()
		return
	var cell: FieldCellState = snapshot.get_cell(_inspected_coordinates)
	if cell == null:
		_on_inspector_closed()
		return
	var crop: CropData = null
	if cell.has_crop:
		crop = farming_controller.crop_database.get_crop(cell.crop_type)
	tile_inspector.display_cell(cell, crop)
	var disease: DiseaseData = turn_controller.disease_database.get_disease(playtest_disease_id) if turn_controller.disease_database != null else null
	tile_inspector.set_seed_available(cell.has_crop and disease != null and cell.crop_type == disease.target_crop and not cell.has_active_disease and cell.susceptible_fraction == 1.0)


func _on_inspector_closed() -> void:
	_inspected_coordinates = Vector2i(-1, -1)
	tile_inspector.clear_display()
	if not _planting_enabled:
		status_label.text = "Click another tile to inspect it."


func _on_seed_infection_requested() -> void:
	if not _running or _planting_enabled or _inspected_coordinates.x < 0:
		return
	if farming_controller.seed_infection(_inspected_coordinates, playtest_disease_id, turn_controller.disease_database, turn_controller.simulation_controller):
		status_label.text = "Patient zero seeded. Next Turn advances disease spread."
	else:
		status_label.text = farming_controller.last_error


func _on_algorithm_selected(index: int) -> void:
	if not _running:
		return
	# Baked order: default, SIR, SEIR, CA. No runtime item creation.
	if not turn_controller.try_set_algorithm_override(index - 1):
		status_label.text = turn_controller.last_error
	else:
		status_label.text = "Algorithm selected: " + algorithm_selector.get_item_text(index)
	_sync_algorithm_selector()
	_refresh_inspected_cell()


func _sync_algorithm_selector() -> void:
	if algorithm_selector != null:
		algorithm_selector.select(turn_controller.simulation_controller.algorithm_override + 1)


func _on_sugarcane_pressed() -> void:
	_select_crop(SimulationEnums.CropType.SUGARCANE)


func _on_rice_pressed() -> void:
	_select_crop(SimulationEnums.CropType.RICE)


func _on_corn_pressed() -> void:
	_select_crop(SimulationEnums.CropType.CORN)


func _on_cell_clicked(coordinates: Vector2i) -> void:
	if not _running:
		return
	if _tool_mode == ToolMode.TOOL_REMOVE:
		if farming_controller.remove_crop(coordinates):
			status_label.text = "Crop removed. Choose another crop or switch tools."
		else:
			status_label.text = farming_controller.last_error
		return
	if _tool_mode == ToolMode.TOOL_TRANSFER:
		_handle_transfer_click(coordinates)
		return
	if _planting_enabled:
		farming_controller.try_plant(coordinates, _selected_crop)
	else:
		_inspected_coordinates = coordinates
		_refresh_inspected_cell()


func _on_cell_changed(coordinates: Vector2i) -> void:
	world_view.refresh_crops(farming_controller.get_grid_snapshot(), farming_controller.crop_database)
	if coordinates == _inspected_coordinates:
		_refresh_inspected_cell()
	if _planting_enabled:
		status_label.text = "Planted at (%d, %d). Next Turn advances growth." % [coordinates.x, coordinates.y]


func _on_planting_rejected(_coordinates: Vector2i, reason: String) -> void:
	status_label.text = reason


func _on_next_turn_pressed() -> void:
	if _running and not turn_controller.advance_turn():
		status_label.text = turn_controller.last_error


func _on_turn_completed(turn_index: int) -> void:
	_transfer_source = Vector2i(-1, -1)
	world_view.refresh_crops(farming_controller.get_grid_snapshot(), farming_controller.crop_database)
	_refresh_inspected_cell()
	turn_label.text = "Turn: %d" % turn_index
	status_label.text = "Growth advanced. Mature crops have reached 100% growth."
	if _tool_mode == ToolMode.TOOL_TRANSFER:
		status_label.text = "Turn advanced. Choose a crop to move."
	elif _tool_mode == ToolMode.TOOL_REMOVE:
		status_label.text = "Turn advanced. Choose a crop to remove."


func _on_remove_pressed() -> void:
	_select_management_tool(ToolMode.TOOL_REMOVE)


func _on_transfer_pressed() -> void:
	_select_management_tool(ToolMode.TOOL_TRANSFER)


func _select_management_tool(mode: ToolMode) -> void:
	if not _running:
		return
	if _tool_mode == mode:
		_enter_inspect_mode()
		return
	_planting_enabled = false
	_tool_mode = mode
	_transfer_source = Vector2i(-1, -1)
	_inspected_coordinates = Vector2i(-1, -1)
	tile_inspector.clear_display()
	_update_crop_buttons()
	selected_crop_label.text = "Tool: Shovel" if mode == ToolMode.TOOL_REMOVE else "Tool: Move"
	status_label.text = "Click a crop to destroy it." if mode == ToolMode.TOOL_REMOVE else "Click a crop, then an empty compatible tile."


func _handle_transfer_click(coordinates: Vector2i) -> void:
	if _transfer_source.x < 0:
		var snapshot: FieldGridState = farming_controller.get_grid_snapshot()
		var cell: FieldCellState = snapshot.get_cell(coordinates)
		if cell == null or not cell.has_crop:
			status_label.text = "Choose a crop to move first."
			return
		_transfer_source = coordinates
		status_label.text = "Moving (%d, %d): choose an empty compatible tile. Click source to cancel." % [coordinates.x, coordinates.y]
		return
	if coordinates == _transfer_source:
		_transfer_source = Vector2i(-1, -1)
		status_label.text = "Move cancelled. Choose another crop."
		return
	if farming_controller.transfer_crop(_transfer_source, coordinates):
		_transfer_source = Vector2i(-1, -1)
		status_label.text = "Crop moved. Choose another crop to move."
	else:
		status_label.text = farming_controller.last_error + " Choose another destination or click the source to cancel."


func _unhandled_key_input(event: InputEvent) -> void:
	if _running and event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		if key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
			_enter_inspect_mode()
			get_viewport().set_input_as_handled()


func _show_failure(message: String) -> void:
	_running = false
	for button: Button in [remove_button, transfer_button]:
		if button != null:
			button.disabled = true
	if tile_inspector != null:
		tile_inspector.clear_display()
	if world_view != null:
		world_view.set_interaction_enabled(false)
	if next_turn_button != null:
		next_turn_button.disabled = true
	if sugarcane_button != null:
		sugarcane_button.disabled = true
	if rice_button != null:
		rice_button.disabled = true
	if corn_button != null:
		corn_button.disabled = true
	if status_label != null:
		status_label.text = message
	push_error(message)


func _refresh_camera_button() -> void:
	if camera_zoom_button != null:
		camera_zoom_button.text = "Reset view" if world_view.camera.zoom.x > world_view.min_zoom + 0.00001 else "Zoom in"
