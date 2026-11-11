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
@export var harvest_button: Button
@export var water_button: Button
@export var fertilize_button: Button
@export var fence_button: Button
@export var hoe_button: Button

@export_group("Pause")
@export var pause_button: Button
@export var pause_menu: PauseMenuView

@export_group("Logic")
@export var soil_tool_controller: SoilToolController
@export var water_bucket_button: Button
@export var game_state_manager: GameStateManager
@export_group("Treatments")
@export var treatment_controller: TreatmentController
@export var treatment_panel: TreatmentPanel
@export var fungicide_button: Button
@export var bactericide_button: Button
@export var protectant_button: Button
@export var enhancer_button: Button
enum ToolMode { INSPECT, PLANT, TOOL_REMOVE, TOOL_TRANSFER, TOOL_HARVEST, TOOL_WATER, TOOL_FERTILIZE, TOOL_WATER_BUCKET, TOOL_FUNGICIDE, TOOL_BACTERICIDE, TOOL_PROTECTANT, TOOL_ENHANCER, TOOL_FENCE, TOOL_HOE }
var _tool_mode: ToolMode = ToolMode.INSPECT
var _transfer_source: Vector2i = Vector2i(-1, -1)
@export var playtest_disease_id: SimulationEnums.DiseaseId = SimulationEnums.DiseaseId.RICE_BLAST
var _selected_crop: SimulationEnums.CropType = SimulationEnums.CropType.SUGARCANE
var _running: bool = false
var _planting_enabled: bool = false
var _inspected_coordinates: Vector2i = Vector2i(-1, -1)
var _start_overlay: CanvasLayer
var _end_overlay: CanvasLayer
var _end_overlay_title: Label
var _end_overlay_details: Label
var _end_overlay_score: Label
var _end_overlay_breakdown: Label
var _end_overlay_button: Button
var _score_label: Label


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
	for button: Button in [remove_button, transfer_button, harvest_button, water_button, fertilize_button, water_bucket_button, fence_button, hoe_button]:
		if button != null:
			button.toggle_mode = true
			button.set_pressed_no_signal(false)
	_connect_signals()
	errors = world_view.validate_configuration()
	if not errors.is_empty():
		_show_failure("\n".join(errors))
		return
	# Game loop setup.
	if game_state_manager == null:
		game_state_manager = GameStateManager.new()
		add_child(game_state_manager)
	turn_controller.game_state_manager = game_state_manager
	if treatment_controller != null:
		farming_controller.treatment_controller = treatment_controller
	_create_overlays()
	_connect_game_signals()
	next_turn_button.text = "End Turn"
	# All listeners are connected before Logic emits its initialization signal.
	if not farming_controller.initialize_field():
		_show_failure(farming_controller.last_error)


func _connect_once(source: Signal, callback: Callable) -> void:
	if not source.is_connected(callback):
		source.connect(callback)


func _connect_signals() -> void:
	if water_bucket_button != null:
		world_view.register_ui_input_root(water_bucket_button)
		_connect_once(water_bucket_button.pressed, _on_water_bucket_pressed)
	if fence_button != null:
		world_view.register_ui_input_root(fence_button)
		_connect_once(fence_button.pressed, _on_fence_pressed)
	if world_view.farmer_agent != null:
		_connect_once(world_view.farmer_agent.arrived, _on_farmer_arrived)
	_connect_once(world_view.cells_selected, _on_cells_selected)
	_connect_once(farming_controller.action_queue_changed, _on_action_queue_changed)
	_connect_once(farming_controller.action_finished, _on_action_finished)
	_connect_once(farming_controller.queued_harvest_completed, _on_queued_harvest_completed)
	if water_button != null:
		world_view.register_ui_input_root(water_button)
		_connect_once(water_button.pressed, _on_water_pressed)
	if fertilize_button != null:
		world_view.register_ui_input_root(fertilize_button)
		_connect_once(fertilize_button.pressed, _on_fertilize_pressed)
	if harvest_button != null:
		world_view.register_ui_input_root(harvest_button)
		_connect_once(harvest_button.pressed, _on_harvest_pressed)
	world_view.register_ui_input_root(hud_panel)
	world_view.register_ui_input_root(tile_inspector)
	if camera_zoom_button != null:
		world_view.register_ui_input_root(camera_zoom_button)
		_connect_once(camera_zoom_button.pressed, world_view.toggle_inspection_zoom)
		_connect_once(world_view.camera_view_changed, _refresh_camera_button)

	if pause_button != null:
		world_view.register_ui_input_root(pause_button)
		_connect_once(pause_button.pressed, _on_pause_requested)
	if pause_menu != null:
		_connect_once(pause_menu.continue_pressed, _on_continue_requested)
		_connect_once(pause_menu.exit_to_menu_pressed, _on_exit_to_menu_requested)

	if remove_button != null:
		_connect_once(remove_button.pressed, _on_remove_pressed)
	if hoe_button != null:
		_connect_once(hoe_button.pressed, _on_hoe_pressed)
	if transfer_button != null:
		_connect_once(transfer_button.pressed, _on_transfer_pressed)
	if fungicide_button != null:
		world_view.register_ui_input_root(fungicide_button)
		_connect_once(fungicide_button.pressed, _on_fungicide_pressed)
	if bactericide_button != null:
		world_view.register_ui_input_root(bactericide_button)
		_connect_once(bactericide_button.pressed, _on_bactericide_pressed)
	if protectant_button != null:
		world_view.register_ui_input_root(protectant_button)
		_connect_once(protectant_button.pressed, _on_protectant_pressed)
	if enhancer_button != null:
		world_view.register_ui_input_root(enhancer_button)
		_connect_once(enhancer_button.pressed, _on_enhancer_pressed)
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
	if world_view.farmer_agent != null:
		world_view.farmer_agent.global_position = world_view.standing_point(Vector2i.ZERO, world_view.terrain_layer.to_global(world_view.terrain_layer.map_to_local(Vector2i(-1, 0))))
	_enter_inspect_mode()
	turn_label.text = "Turn: 0"
	_sync_algorithm_selector()
	_update_score_display()
	# Run again after the scene's first layout pass.
	world_view.frame_field.call_deferred()
	# Gate controls by game state: show start screen on first init, enable on restart.
	if game_state_manager.current_state == GameStateManager.State.MENU:
		_start_overlay.visible = true
	elif game_state_manager.is_playing():
		_set_controls_enabled(true)


func _set_controls_enabled(enabled: bool) -> void:
	for button: Button in [remove_button, transfer_button, harvest_button, water_button, fertilize_button, pause_button, water_bucket_button, fungicide_button, bactericide_button, protectant_button, enhancer_button, fence_button, hoe_button]:
		if button != null:
			button.disabled = not enabled
	next_turn_button.disabled = not enabled
	var catalog: CropDatabase = farming_controller.crop_database
	sugarcane_button.disabled = not enabled or catalog == null or not catalog.has_crop(SimulationEnums.CropType.SUGARCANE)
	rice_button.disabled = not enabled or catalog == null or not catalog.has_crop(SimulationEnums.CropType.RICE)
	corn_button.disabled = not enabled or catalog == null or not catalog.has_crop(SimulationEnums.CropType.CORN)


func _select_crop(crop_type: SimulationEnums.CropType) -> void:
	if not _running or not game_state_manager.is_playing():
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
	_refresh_tool_targets(true)
	if water_bucket_button != null:
		water_bucket_button.set_pressed_no_signal(_tool_mode == ToolMode.TOOL_WATER_BUCKET)
	if fence_button != null:
		fence_button.set_pressed_no_signal(_tool_mode == ToolMode.TOOL_FENCE)
	if water_button != null:
		water_button.set_pressed_no_signal(_tool_mode == ToolMode.TOOL_WATER)
	if fertilize_button != null:
		fertilize_button.set_pressed_no_signal(_tool_mode == ToolMode.TOOL_FERTILIZE)
	if harvest_button != null:
		harvest_button.set_pressed_no_signal(_tool_mode == ToolMode.TOOL_HARVEST)
	if hoe_button != null:
		hoe_button.set_pressed_no_signal(_tool_mode == ToolMode.TOOL_HOE)
	if remove_button != null:
		remove_button.set_pressed_no_signal(_tool_mode == ToolMode.TOOL_REMOVE)
	if transfer_button != null:
		transfer_button.set_pressed_no_signal(_tool_mode == ToolMode.TOOL_TRANSFER)
	if fungicide_button != null:
		fungicide_button.set_pressed_no_signal(_tool_mode == ToolMode.TOOL_FUNGICIDE)
	if bactericide_button != null:
		bactericide_button.set_pressed_no_signal(_tool_mode == ToolMode.TOOL_BACTERICIDE)
	if protectant_button != null:
		protectant_button.set_pressed_no_signal(_tool_mode == ToolMode.TOOL_PROTECTANT)
	if enhancer_button != null:
		enhancer_button.set_pressed_no_signal(_tool_mode == ToolMode.TOOL_ENHANCER)
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
	if not _running or not game_state_manager.is_playing() or _planting_enabled or _inspected_coordinates.x < 0:
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
	if not _running or not game_state_manager.is_playing():
		return
	if _tool_mode == ToolMode.TOOL_TRANSFER:
		_handle_transfer_click(coordinates)
		return
	if _tool_mode != ToolMode.INSPECT:
		_queue_at(coordinates)
	else:
		_inspected_coordinates = coordinates
		_refresh_inspected_cell()


func _on_cell_changed(coordinates: Vector2i) -> void:
	var snapshot: FieldGridState = farming_controller.get_grid_snapshot()
	world_view.render_grid(snapshot)
	world_view.refresh_crops(snapshot, farming_controller.crop_database)
	_refresh_tool_targets()
	if coordinates == _inspected_coordinates:
		_refresh_inspected_cell()
	if _planting_enabled:
		status_label.text = "Planted at (%d, %d). Next Turn advances growth." % [coordinates.x, coordinates.y]


func _on_planting_rejected(_coordinates: Vector2i, reason: String) -> void:
	status_label.text = reason


func _on_next_turn_pressed() -> void:
	if _running and game_state_manager.is_playing() and not turn_controller.advance_turn():
		status_label.text = turn_controller.last_error


func _on_turn_completed(turn_index: int) -> void:
	_transfer_source = Vector2i(-1, -1)
	world_view.refresh_crops(farming_controller.get_grid_snapshot(), farming_controller.crop_database)
	_refresh_tool_targets()
	_refresh_inspected_cell()
	turn_label.text = "Turn: %d" % turn_index
	if treatment_panel != null and treatment_controller != null:
		treatment_panel.refresh(turn_index)
	status_label.text = "Growth advanced. Mature crops have reached 100% growth."
	if _tool_mode == ToolMode.TOOL_TRANSFER:
		status_label.text = "Turn advanced. Choose a crop to move."
	elif _tool_mode == ToolMode.TOOL_REMOVE:
		status_label.text = "Turn advanced. Choose a crop to remove."


func _on_water_pressed() -> void:
	_select_management_tool(ToolMode.TOOL_WATER)


func _on_water_bucket_pressed() -> void:
	_select_management_tool(ToolMode.TOOL_WATER_BUCKET)


func _on_fence_pressed() -> void:
	_select_management_tool(ToolMode.TOOL_FENCE)


func _on_fertilize_pressed() -> void:
	_select_management_tool(ToolMode.TOOL_FERTILIZE)


func _on_harvest_pressed() -> void:
	_select_management_tool(ToolMode.TOOL_HARVEST)


func _on_remove_pressed() -> void:
	_select_management_tool(ToolMode.TOOL_REMOVE)


func _on_hoe_pressed() -> void:
	_select_management_tool(ToolMode.TOOL_HOE)


func _on_transfer_pressed() -> void:
	_select_management_tool(ToolMode.TOOL_TRANSFER)


func _on_fungicide_pressed() -> void:
	_select_management_tool(ToolMode.TOOL_FUNGICIDE)


func _on_bactericide_pressed() -> void:
	_select_management_tool(ToolMode.TOOL_BACTERICIDE)


func _on_protectant_pressed() -> void:
	_select_management_tool(ToolMode.TOOL_PROTECTANT)


func _on_enhancer_pressed() -> void:
	_select_management_tool(ToolMode.TOOL_ENHANCER)


func _select_management_tool(mode: ToolMode) -> void:
	if not _running or not game_state_manager.is_playing():
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
	if mode == ToolMode.TOOL_FENCE:
		selected_crop_label.text = "Tool: Fence"
		status_label.text = "Click or drag over tiles to fence them."
		return
	if mode == ToolMode.TOOL_WATER_BUCKET:
		selected_crop_label.text = "Tool: Water Bucket"
		status_label.text = "Drag over empty dry soil to queue paddy conversion."
		return
	if mode in [ToolMode.TOOL_FUNGICIDE, ToolMode.TOOL_BACTERICIDE, ToolMode.TOOL_PROTECTANT, ToolMode.TOOL_ENHANCER]:
		var tname: String = "Fungicide" if mode == ToolMode.TOOL_FUNGICIDE else "Bactericide" if mode == ToolMode.TOOL_BACTERICIDE else "Protectant" if mode == ToolMode.TOOL_PROTECTANT else "Enhancer"
		selected_crop_label.text = "Tool: %s" % tname
		status_label.text = "Click a crop tile to queue %s treatment." % tname.to_lower()
		return
	if mode in [ToolMode.TOOL_WATER, ToolMode.TOOL_FERTILIZE]:
		selected_crop_label.text = "Tool: Water" if mode == ToolMode.TOOL_WATER else "Tool: Fertilize"
		status_label.text = "Click a soil tile to apply the selected tool."
		return
	if mode == ToolMode.TOOL_HARVEST:
		selected_crop_label.text = "Tool: Harvest"
		status_label.text = "Click a mature crop to collect its yield quality."
		return
	if mode == ToolMode.TOOL_HOE:
		selected_crop_label.text = "Tool: Hoe"
		status_label.text = "Click or drag over empty grass to till it."
		return
	selected_crop_label.text = "Tool: Shovel" if mode == ToolMode.TOOL_REMOVE else "Tool: Move"
	status_label.text = "Drag over crops or fences to remove. The first eligible plot locks the action." if mode == ToolMode.TOOL_REMOVE else "Click a crop, then an empty compatible tile."


func _handle_transfer_click(coordinates: Vector2i) -> void:
	if _transfer_source.x < 0:
		var snapshot: FieldGridState = farming_controller.get_grid_snapshot()
		var cell: FieldCellState = snapshot.get_cell(coordinates)
		if cell == null or not cell.has_crop:
			status_label.text = "Choose a crop to move first."
			return
		_transfer_source = coordinates
		_refresh_tool_targets(true)
		status_label.text = "Moving (%d, %d): choose an empty compatible tile. Click source to cancel." % [coordinates.x, coordinates.y]
		return
	if coordinates == _transfer_source:
		_transfer_source = Vector2i(-1, -1)
		_refresh_tool_targets(true)
		status_label.text = "Move cancelled. Choose another crop."
		return
	if _queue_at(coordinates):
		_transfer_source = Vector2i(-1, -1)
		_refresh_tool_targets(true)
		status_label.text = "Move queued. The farmer will visit both plots."
	else:
		status_label.text = farming_controller.last_error + " Choose another destination or click the source to cancel."


func _unhandled_key_input(event: InputEvent) -> void:
	# The pause menu (process_mode ALWAYS) handles Escape while paused; this
	# presenter is pausable and does not receive input once the tree is paused.
	if not _running or get_tree().paused or not (event is InputEventKey):
		return
	var key: InputEventKey = event as InputEventKey
	if key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		_open_pause_menu()
		get_viewport().set_input_as_handled()


func _show_failure(message: String) -> void:
	_running = false
	for button: Button in [remove_button, transfer_button, harvest_button, water_button, fertilize_button, pause_button, water_bucket_button, fungicide_button, bactericide_button, protectant_button, enhancer_button, fence_button, hoe_button]:
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


# --- Pause menu ---------------------------------------------------------------

func _open_pause_menu() -> void:
	if pause_menu == null or get_tree().paused:
		return
	pause_menu.show_menu()
	get_tree().paused = true


func _on_pause_requested() -> void:
	if not _running or get_tree().paused:
		return
	_open_pause_menu()


func _on_continue_requested() -> void:
	if pause_menu == null:
		return
	pause_menu.hide_menu()
	get_tree().paused = false


func _on_exit_to_menu_requested() -> void:
	# Unpause before leaving so the destination scene starts in a normal state.
	get_tree().paused = false
	get_tree().change_scene_to_file("res://src/presentation/menu/main_menu.tscn")


func _make_action(coordinates: Vector2i, known_cell: FieldCellState = null) -> FieldAction:
	var action: FieldAction = FieldAction.new()
	action.target = coordinates
	action.crop_type = _selected_crop
	action.source = _transfer_source
	match _tool_mode:
		ToolMode.TOOL_HOE:
			action.kind = SimulationEnums.FieldActionKind.DIG_GRASS
		ToolMode.TOOL_REMOVE:
			var cell: FieldCellState = known_cell if known_cell != null else farming_controller.get_grid_snapshot().get_cell(coordinates)
			if cell != null and cell.has_fence:
				action.kind = SimulationEnums.FieldActionKind.REMOVE_FENCE
			else:
				action.kind = SimulationEnums.FieldActionKind.REMOVE_CROP
		ToolMode.TOOL_FENCE:
			action.kind = SimulationEnums.FieldActionKind.FENCE
		ToolMode.TOOL_WATER_BUCKET:
			action.kind = SimulationEnums.FieldActionKind.MAKE_PADDY
		ToolMode.TOOL_TRANSFER:
			action.kind = SimulationEnums.FieldActionKind.MOVE_CROP
		ToolMode.TOOL_HARVEST:
			action.kind = SimulationEnums.FieldActionKind.HARVEST
		ToolMode.TOOL_WATER:
			action.kind = SimulationEnums.FieldActionKind.WATER_SOIL
			action.additions = Vector3(soil_tool_controller.water_infusion_amount, 0, 0) if soil_tool_controller != null else Vector3.INF
		ToolMode.TOOL_FERTILIZE:
			action.kind = SimulationEnums.FieldActionKind.FERTILIZE
			action.additions = Vector3(0, soil_tool_controller.nitrogen_boost_amount, soil_tool_controller.potassium_boost_amount) if soil_tool_controller != null else Vector3.INF
		ToolMode.TOOL_FUNGICIDE:
			action.kind = SimulationEnums.FieldActionKind.APPLY_FUNGICIDE
		ToolMode.TOOL_BACTERICIDE:
			action.kind = SimulationEnums.FieldActionKind.APPLY_BACTERICIDE
		ToolMode.TOOL_PROTECTANT:
			action.kind = SimulationEnums.FieldActionKind.APPLY_PROTECTANT
		ToolMode.TOOL_ENHANCER:
			action.kind = SimulationEnums.FieldActionKind.APPLY_ENHANCER
		_:
			action.kind = SimulationEnums.FieldActionKind.PLANT
	return action


func _queue_at(coordinates: Vector2i, expected_kind: int = -1) -> bool:
	if world_view.farmer_agent == null:
		status_label.text = "Assign FarmerAgent before queuing actions."
		return false
	var action: FieldAction = _make_action(coordinates)
	if expected_kind >= 0 and action.kind != expected_kind:
		return false
	var success: bool = farming_controller.enqueue_action(action)
	status_label.text = "Action queued. The farmer is on the way." if success else farming_controller.last_error
	return success


func _on_cells_selected(coordinates: Array[Vector2i], kind: int) -> void:
	if not _running or not game_state_manager.is_playing() or _tool_mode == ToolMode.INSPECT:
		return
	for coords: Vector2i in coordinates:
		_queue_at(coords, kind)


func _refresh_tool_targets(mode_changed: bool = false) -> void:
	if world_view == null or not farming_controller.is_initialized():
		return
	var eligible: Dictionary[Vector2i, int] = {}
	var snapshot: FieldGridState = farming_controller.get_grid_snapshot()
	var reserved: Array[Vector2i] = farming_controller.get_queued_coordinates()
	if _tool_mode != ToolMode.INSPECT:
		for y: int in range(snapshot.height):
			for x: int in range(snapshot.width):
				var coords: Vector2i = Vector2i(x, y)
				if _tool_mode == ToolMode.TOOL_TRANSFER and _transfer_source.x < 0:
					if snapshot.get_cell(coords).has_crop and not reserved.has(coords):
						eligible[coords] = SimulationEnums.FieldActionKind.MOVE_CROP
				elif _tool_mode == ToolMode.TOOL_TRANSFER and coords == _transfer_source:
					eligible[coords] = SimulationEnums.FieldActionKind.MOVE_CROP
				else:
					var action: FieldAction = _make_action(coords, snapshot.get_cell(coords))
					if farming_controller.action_error(action).is_empty():
						eligible[coords] = action.kind
	world_view.configure_tool(_tool_mode != ToolMode.INSPECT, _tool_mode != ToolMode.TOOL_TRANSFER, eligible, mode_changed)
	world_view.show_queued(reserved, _transfer_source)


func _on_action_queue_changed() -> void:
	_refresh_tool_targets()
	if next_turn_button != null:
		next_turn_button.disabled = not _running or game_state_manager == null or not game_state_manager.is_playing() or farming_controller.has_pending_actions()
	var agent: FarmerAgent = world_view.farmer_agent
	if agent == null:
		return
	var action: FieldAction = farming_controller.get_current_action()
	if action == null:
		agent.stop()
	else:
		var stop: Vector2i = action.stop_coordinates()
		agent.walk_to(action.id, stop, world_view.standing_point(stop, agent.global_position))


func _on_farmer_arrived(action_id: int, coordinates: Vector2i) -> void:
	farming_controller.arrive_at_action(action_id, coordinates)


func _on_action_finished(action_id: int, success: bool, reason: String) -> void:
	if not success and reason.is_empty():
		status_label.text = "Action failed."
	elif not success:
		# Check for treatment-specific cues (cooldown, mismatch)
		if reason.contains("cooldown"):
			status_label.text = "Treatment discarded: %s" % reason
		else:
			status_label.text = reason
	else:
		status_label.text = "Action complete."
	# Refresh treatment panel on action completion
	if treatment_panel != null and treatment_controller != null:
		var turn: int = turn_controller.turn_index if turn_controller != null else 0
		treatment_panel.refresh(turn)
	# Show expiry cues from treatment state
	if treatment_controller != null and treatment_controller.treatment_state != null:
		for ev: Dictionary in treatment_controller.treatment_state.events:
			if ev.get("type", "") == "expired":
				status_label.text = "%s expired at (%d, %d)." % [ev.get("treatment_id", ""), ev.get("cell_x", 0), ev.get("cell_y", 0)]


func _on_queued_harvest_completed(result: HarvestResult) -> void:
	status_label.text = "Harvested: %.0f%% yield quality." % (100.0 * result.quality_multiplier) if result.success else result.reason
	game_state_manager.record_harvest(result)


func _create_overlays() -> void:
	# --- Start screen overlay ---
	_start_overlay = CanvasLayer.new()
	_start_overlay.layer = 10
	_start_overlay.visible = false
	add_child(_start_overlay)
	var start_bg := ColorRect.new()
	start_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	start_bg.color = Color(0.0, 0.0, 0.0, 0.7)
	start_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_start_overlay.add_child(start_bg)
	var start_center := CenterContainer.new()
	start_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_start_overlay.add_child(start_center)
	var start_vbox := VBoxContainer.new()
	start_vbox.custom_minimum_size = Vector2(420, 0)
	start_vbox.add_theme_constant_override("separation", 16)
	start_center.add_child(start_vbox)
	var start_title := Label.new()
	start_title.text = "Farming Simulator"
	start_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	start_title.add_theme_font_size_override("font_size", 28)
	start_vbox.add_child(start_title)
	var start_blurb := Label.new()
	var start_blurb_text := "Plant crops, manage soil, and harvest before the turn limit.\nGoal: reach %d points in %d turns." % [game_state_manager.score_goal, game_state_manager.turn_limit]
	if farming_controller != null and farming_controller.crop_database != null:
		var values := PackedStringArray()
		var crop_types: Array[SimulationEnums.CropType] = [SimulationEnums.CropType.SUGARCANE, SimulationEnums.CropType.CORN, SimulationEnums.CropType.RICE]
		for crop_type: SimulationEnums.CropType in crop_types:
			var c: CropData = farming_controller.crop_database.get_crop(crop_type)
			if c != null:
				values.append("%s: %d" % [c.display_name, c.base_score])
		if not values.is_empty():
			start_blurb_text += "\nPer harvest: " + " - ".join(values) + " (quality reduces score)."
	start_blurb.text = start_blurb_text
	start_blurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	start_vbox.add_child(start_blurb)
	var start_button := Button.new()
	start_button.text = "Start Game"
	start_button.custom_minimum_size = Vector2(200, 48)
	start_button.size_flags_horizontal = Control.SIZE_EXPAND
	_connect_once(start_button.pressed, _on_start_pressed)
	start_vbox.add_child(start_button)
	# --- End screen overlay ---
	_end_overlay = CanvasLayer.new()
	_end_overlay.layer = 10
	_end_overlay.visible = false
	add_child(_end_overlay)
	var end_bg := ColorRect.new()
	end_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	end_bg.color = Color(0.0, 0.0, 0.0, 0.7)
	end_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_end_overlay.add_child(end_bg)
	var end_center := CenterContainer.new()
	end_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_end_overlay.add_child(end_center)
	var end_vbox := VBoxContainer.new()
	end_vbox.custom_minimum_size = Vector2(420, 0)
	end_vbox.add_theme_constant_override("separation", 16)
	end_center.add_child(end_vbox)
	_end_overlay_title = Label.new()
	_end_overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_overlay_title.add_theme_font_size_override("font_size", 28)
	end_vbox.add_child(_end_overlay_title)
	_end_overlay_score = Label.new()
	_end_overlay_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_overlay_score.add_theme_font_size_override("font_size", 22)
	end_vbox.add_child(_end_overlay_score)
	_end_overlay_breakdown = Label.new()
	_end_overlay_breakdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_vbox.add_child(_end_overlay_breakdown)
	_end_overlay_details = Label.new()
	_end_overlay_details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_vbox.add_child(_end_overlay_details)
	_end_overlay_button = Button.new()
	_end_overlay_button.text = "Play Again"
	_end_overlay_button.custom_minimum_size = Vector2(200, 48)
	_end_overlay_button.size_flags_horizontal = Control.SIZE_EXPAND
	_connect_once(_end_overlay_button.pressed, _on_play_again_pressed)
	end_vbox.add_child(_end_overlay_button)
	# --- Score label in HUD ---
	_score_label = Label.new()
	_score_label.text = "Score: 0 / %d" % game_state_manager.score_goal
	var controls: VBoxContainer = hud_panel.get_node("Margin/Controls")
	controls.add_child(_score_label)
	controls.move_child(_score_label, 1)


func _connect_game_signals() -> void:
	_connect_once(game_state_manager.state_changed, _on_game_state_changed)
	_connect_once(game_state_manager.score_changed, _on_score_changed)
	_connect_once(game_state_manager.game_ended, _on_game_ended)


func _on_start_pressed() -> void:
	game_state_manager.start_game()


func _on_game_state_changed(_old_state: GameStateManager.State, new_state: GameStateManager.State) -> void:
	match new_state:
		GameStateManager.State.PLAYING:
			_start_overlay.visible = false
			_end_overlay.visible = false
			if _running:
				_set_controls_enabled(true)
		GameStateManager.State.GAME_OVER, GameStateManager.State.VICTORY:
			_set_controls_enabled(false)
		GameStateManager.State.MENU:
			_set_controls_enabled(false)
			_end_overlay.visible = false
			_start_overlay.visible = true


func _on_score_changed(_total_score: float, _goal: int) -> void:
	_update_score_display()


func _update_score_display() -> void:
	if _score_label != null and game_state_manager != null:
		_score_label.text = "Score: %d / %d" % [roundi(game_state_manager.total_score), game_state_manager.score_goal]


func _on_game_ended(victory: bool) -> void:
	_set_controls_enabled(false)
	_end_overlay_score.text = "Final Score: %d / %d" % [roundi(game_state_manager.total_score), game_state_manager.score_goal]
	_end_overlay_breakdown.text = _build_score_breakdown()
	if victory:
		_end_overlay_title.text = "Victory!"
		_end_overlay_title.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))
		_end_overlay_details.text = "Goal reached in %d turns with %d harvests." % [game_state_manager.turns_reached, game_state_manager.harvest_count]
	else:
		_end_overlay_title.text = "Game Over"
		_end_overlay_title.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
		_end_overlay_details.text = "Out of turns (%d). %d harvests scored %d of %d points." % [game_state_manager.turn_limit, game_state_manager.harvest_count, roundi(game_state_manager.total_score), game_state_manager.score_goal]
	_end_overlay_button.text = "Play Again"
	_end_overlay.visible = true


func _build_score_breakdown() -> String:
	if game_state_manager == null or game_state_manager.crop_tally.is_empty():
		return "No harvests yet."
	var names: Dictionary = {
		SimulationEnums.CropType.SUGARCANE: "Sugarcane",
		SimulationEnums.CropType.RICE: "Rice",
		SimulationEnums.CropType.CORN: "Corn",
	}
	var lines: PackedStringArray = PackedStringArray()
	var keys: Array = game_state_manager.crop_tally.keys()
	keys.sort()
	for key: int in keys:
		var tally: GameStateManager.CropTally = game_state_manager.crop_tally[key] as GameStateManager.CropTally
		if tally == null:
			continue
		var crop_name: String = names.get(key, "Crop %d" % key) as String
		lines.append("%s: %d harvests - %d pts" % [crop_name, tally.count, roundi(tally.score)])
	return "\n".join(lines)


func _on_play_again_pressed() -> void:
	_end_overlay.visible = false
	if not farming_controller.initialize_field():
		_show_failure(farming_controller.last_error)
		return
	game_state_manager.start_game()
