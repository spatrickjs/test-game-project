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
	# Run again after the scene's first layout pass.
	world_view.frame_field.call_deferred()


func _set_controls_enabled(enabled: bool) -> void:
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
	_selected_crop = crop_type
	_inspected_coordinates = Vector2i(-1, -1)
	tile_inspector.clear_display()
	_update_crop_buttons()
	selected_crop_label.text = "Plant: %s" % crop.display_name
	status_label.text = "Click an eligible tile to plant. Click this crop button again to inspect."


func _enter_inspect_mode() -> void:
	_planting_enabled = false
	_inspected_coordinates = Vector2i(-1, -1)
	tile_inspector.clear_display()
	_update_crop_buttons()
	selected_crop_label.text = "Mode: Inspect"
	status_label.text = "Click a tile to inspect it, or select a crop to plant."


func _update_crop_buttons() -> void:
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


func _on_inspector_closed() -> void:
	_inspected_coordinates = Vector2i(-1, -1)
	tile_inspector.clear_display()
	if not _planting_enabled:
		status_label.text = "Click another tile to inspect it."


func _on_sugarcane_pressed() -> void:
	_select_crop(SimulationEnums.CropType.SUGARCANE)


func _on_rice_pressed() -> void:
	_select_crop(SimulationEnums.CropType.RICE)


func _on_corn_pressed() -> void:
	_select_crop(SimulationEnums.CropType.CORN)


func _on_cell_clicked(coordinates: Vector2i) -> void:
	if not _running:
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
	world_view.refresh_crops(farming_controller.get_grid_snapshot(), farming_controller.crop_database)
	_refresh_inspected_cell()
	turn_label.text = "Turn: %d" % turn_index
	status_label.text = "Growth advanced. Gold markers are mature."


func _show_failure(message: String) -> void:
	_running = false
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
