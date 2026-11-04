@tool
extends EditorScript
## Run from the Script Editor with field_prototype.tscn active.
## Builds through Godot APIs, sets ownership and exported references, and records
## one Undo/Redo action. Never writes raw scene text, changes UIDs, or auto-saves.
## Runtime signals remain the responsibility of the view and presenter.

const VIEW_SCRIPT: Script = preload("res://src/presentation/ui/inspectors/tile_inspector_view.gd")
const PANEL_PATH: NodePath = ^"HUD/TileInspectorPanel"
## Parent-before-child order is intentional.
const NODE_TYPES: Dictionary[String, StringName] = {
	"HUD": &"CanvasLayer",
	"HUD/Panel": &"PanelContainer",
	"HUD/Panel/Margin": &"MarginContainer",
	"HUD/Panel/Margin/Controls": &"VBoxContainer",
	"HUD/Panel/Margin/Controls/TurnLabel": &"Label",
	"HUD/Panel/Margin/Controls/SelectedCropLabel": &"Label",
	"HUD/Panel/Margin/Controls/CropButtons": &"HBoxContainer",
	"HUD/Panel/Margin/Controls/NextTurnButton": &"Button",
	"HUD/Panel/Margin/Controls/StatusLabel": &"Label",
	"HUD/Panel/Margin/Controls/AlgorithmSelector": &"OptionButton",
	"HUD/Panel/Margin/Controls/CropButtons/SugarcaneButton": &"Button",
	"HUD/Panel/Margin/Controls/CropButtons/RiceButton": &"Button",
	"HUD/Panel/Margin/Controls/CropButtons/CornButton": &"Button",
	"HUD/Panel/Margin/Controls/CropButtons/RemoveButton": &"Button",
	"HUD/Panel/Margin/Controls/CropButtons/TransferButton": &"Button",
	"HUD/TileInspectorPanel": &"PanelContainer",
	"HUD/TileInspectorPanel/Margin": &"MarginContainer",
	"HUD/TileInspectorPanel/Margin/Layout": &"VBoxContainer",
	"HUD/TileInspectorPanel/Margin/Layout/Header": &"HBoxContainer",
	"HUD/TileInspectorPanel/Margin/Layout/Header/TitleLabel": &"Label",
	"HUD/TileInspectorPanel/Margin/Layout/Header/CloseButton": &"Button",
	"HUD/TileInspectorPanel/Margin/Layout/SeedInfectionButton": &"Button",
	"HUD/TileInspectorPanel/Margin/Layout/Scroll": &"ScrollContainer",
	"HUD/TileInspectorPanel/Margin/Layout/Scroll/Content": &"VBoxContainer",
	"HUD/TileInspectorPanel/Margin/Layout/Scroll/Content/TerrainHeading": &"Label",
	"HUD/TileInspectorPanel/Margin/Layout/Scroll/Content/TerrainLabel": &"Label",
	"HUD/TileInspectorPanel/Margin/Layout/Scroll/Content/SoilPHLabel": &"Label",
	"HUD/TileInspectorPanel/Margin/Layout/Scroll/Content/MacronutrientsLabel": &"Label",
	"HUD/TileInspectorPanel/Margin/Layout/Scroll/Content/TerrainSeparator": &"HSeparator",
	"HUD/TileInspectorPanel/Margin/Layout/Scroll/Content/CropHeading": &"Label",
	"HUD/TileInspectorPanel/Margin/Layout/Scroll/Content/CropNameLabel": &"Label",
	"HUD/TileInspectorPanel/Margin/Layout/Scroll/Content/GrowthLabel": &"Label",
	"HUD/TileInspectorPanel/Margin/Layout/Scroll/Content/GrowthBar": &"ProgressBar",
	"HUD/TileInspectorPanel/Margin/Layout/Scroll/Content/DiseaseSeparator": &"HSeparator",
	"HUD/TileInspectorPanel/Margin/Layout/Scroll/Content/EpidemicHeading": &"Label",
	"HUD/TileInspectorPanel/Margin/Layout/Scroll/Content/DiseaseLabel": &"Label",
	"HUD/TileInspectorPanel/Margin/Layout/Scroll/Content/StateLabel": &"Label",
	"HUD/TileInspectorPanel/Margin/Layout/Scroll/Content/RemovedOutcomeLabel": &"Label",
	"HUD/TileInspectorPanel/Margin/Layout/Scroll/Content/FractionsHeading": &"Label",
	"HUD/TileInspectorPanel/Margin/Layout/Scroll/Content/Compartments": &"GridContainer",
	"HUD/TileInspectorPanel/Margin/Layout/Scroll/Content/Compartments/SusceptibleLabel": &"Label",
	"HUD/TileInspectorPanel/Margin/Layout/Scroll/Content/Compartments/SusceptibleBar": &"ProgressBar",
	"HUD/TileInspectorPanel/Margin/Layout/Scroll/Content/Compartments/ExposedLabel": &"Label",
	"HUD/TileInspectorPanel/Margin/Layout/Scroll/Content/Compartments/ExposedBar": &"ProgressBar",
	"HUD/TileInspectorPanel/Margin/Layout/Scroll/Content/Compartments/InfectedLabel": &"Label",
	"HUD/TileInspectorPanel/Margin/Layout/Scroll/Content/Compartments/InfectedBar": &"ProgressBar",
	"HUD/TileInspectorPanel/Margin/Layout/Scroll/Content/Compartments/ImmuneLabel": &"Label",
	"HUD/TileInspectorPanel/Margin/Layout/Scroll/Content/Compartments/ImmuneBar": &"ProgressBar",
	"HUD/TileInspectorPanel/Margin/Layout/Scroll/Content/Compartments/DeadLabel": &"Label",
	"HUD/TileInspectorPanel/Margin/Layout/Scroll/Content/Compartments/DeadBar": &"ProgressBar",
}
const BINDINGS: Dictionary[StringName, NodePath] = {
	&"seed_infection_button": ^"HUD/TileInspectorPanel/Margin/Layout/SeedInfectionButton",
	&"close_button": ^"HUD/TileInspectorPanel/Margin/Layout/Header/CloseButton",
	&"scroll_container": ^"HUD/TileInspectorPanel/Margin/Layout/Scroll",
	&"title_label": ^"HUD/TileInspectorPanel/Margin/Layout/Header/TitleLabel",
	&"terrain_label": ^"HUD/TileInspectorPanel/Margin/Layout/Scroll/Content/TerrainLabel",
	&"soil_ph_label": ^"HUD/TileInspectorPanel/Margin/Layout/Scroll/Content/SoilPHLabel",
	&"macronutrients_label": ^"HUD/TileInspectorPanel/Margin/Layout/Scroll/Content/MacronutrientsLabel",
	&"crop_name_label": ^"HUD/TileInspectorPanel/Margin/Layout/Scroll/Content/CropNameLabel",
	&"growth_label": ^"HUD/TileInspectorPanel/Margin/Layout/Scroll/Content/GrowthLabel",
	&"growth_bar": ^"HUD/TileInspectorPanel/Margin/Layout/Scroll/Content/GrowthBar",
	&"disease_label": ^"HUD/TileInspectorPanel/Margin/Layout/Scroll/Content/DiseaseLabel",
	&"state_label": ^"HUD/TileInspectorPanel/Margin/Layout/Scroll/Content/StateLabel",
	&"removed_outcome_label": ^"HUD/TileInspectorPanel/Margin/Layout/Scroll/Content/RemovedOutcomeLabel",
	&"susceptible_label": ^"HUD/TileInspectorPanel/Margin/Layout/Scroll/Content/Compartments/SusceptibleLabel",
	&"susceptible_bar": ^"HUD/TileInspectorPanel/Margin/Layout/Scroll/Content/Compartments/SusceptibleBar",
	&"exposed_label": ^"HUD/TileInspectorPanel/Margin/Layout/Scroll/Content/Compartments/ExposedLabel",
	&"exposed_bar": ^"HUD/TileInspectorPanel/Margin/Layout/Scroll/Content/Compartments/ExposedBar",
	&"infected_label": ^"HUD/TileInspectorPanel/Margin/Layout/Scroll/Content/Compartments/InfectedLabel",
	&"infected_bar": ^"HUD/TileInspectorPanel/Margin/Layout/Scroll/Content/Compartments/InfectedBar",
	&"immune_label": ^"HUD/TileInspectorPanel/Margin/Layout/Scroll/Content/Compartments/ImmuneLabel",
	&"immune_bar": ^"HUD/TileInspectorPanel/Margin/Layout/Scroll/Content/Compartments/ImmuneBar",
	&"dead_label": ^"HUD/TileInspectorPanel/Margin/Layout/Scroll/Content/Compartments/DeadLabel",
	&"dead_bar": ^"HUD/TileInspectorPanel/Margin/Layout/Scroll/Content/Compartments/DeadBar",
}

const HUD_BINDINGS: Dictionary[StringName, NodePath] = {
	&"algorithm_selector": ^"HUD/Panel/Margin/Controls/AlgorithmSelector",
	&"hud_panel": ^"HUD/Panel",
	&"turn_label": ^"HUD/Panel/Margin/Controls/TurnLabel",
	&"selected_crop_label": ^"HUD/Panel/Margin/Controls/SelectedCropLabel",
	&"status_label": ^"HUD/Panel/Margin/Controls/StatusLabel",
	&"next_turn_button": ^"HUD/Panel/Margin/Controls/NextTurnButton",
	&"sugarcane_button": ^"HUD/Panel/Margin/Controls/CropButtons/SugarcaneButton",
	&"rice_button": ^"HUD/Panel/Margin/Controls/CropButtons/RiceButton",
	&"corn_button": ^"HUD/Panel/Margin/Controls/CropButtons/CornButton",
	&"remove_button": ^"HUD/Panel/Margin/Controls/CropButtons/RemoveButton",
	&"transfer_button": ^"HUD/Panel/Margin/Controls/CropButtons/TransferButton",
}

var _nodes: Dictionary[String, Node] = {}
var _created: Array[Node] = []
var _created_parents: Array[Node] = []
var _changed: bool = false


func _run() -> void:
	var scene_root: Node = EditorInterface.get_edited_scene_root()
	if scene_root == null:
		push_error("Open field_prototype.tscn before running this builder.")
		return
	var root_script: Script = scene_root.get_script() as Script
	if root_script == null or root_script.get_global_name() != &"FieldPrototypePresenter":
		push_error("The active scene root must have field_prototype_presenter.gd attached.")
		return
	if not _prepare(scene_root):
		return
	var panel: PanelContainer = _nodes[String(PANEL_PATH)] as PanelContainer
	var old_inspector: Node = scene_root.get("tile_inspector") as Node
	if old_inspector != null and old_inspector != panel:
		_abort("Presenter already references another inspector. No scene changes were made.")
		return
	var undo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	# Reverse undo operations so bindings restore before child nodes are removed.
	undo.create_action("Bake Field UI", UndoRedo.MERGE_DISABLE, scene_root, true)
	_changed = false
	for index: int in range(_created.size()):
		var node: Node = _created[index]
		var parent: Node = _created_parents[index]
		undo.add_do_method(parent, &"add_child", node, true)
		undo.add_undo_method(parent, &"remove_child", node)
		undo.add_do_reference(node)
		_changed = true
	for path: String in NODE_TYPES:
		var node: Node = _nodes[path]
		_record_property(undo, node, &"owner", scene_root, node.owner)
	var previous_script: Script = panel.get_script() as Script
	_record_property(undo, panel, &"script", VIEW_SCRIPT, previous_script)
	for property_name: StringName in BINDINGS:
		var old_value: Variant = null
		if previous_script == VIEW_SCRIPT:
			old_value = panel.get(property_name)
		_record_property(undo, panel, property_name, _nodes[String(BINDINGS[property_name])], old_value)
	_record_property(undo, scene_root, &"tile_inspector", panel, old_inspector)
	for property_name: StringName in HUD_BINDINGS:
		_record_property(undo, scene_root, property_name, _nodes[String(HUD_BINDINGS[property_name])], scene_root.get(property_name))
	_record_property(undo, panel, &"visible", true, panel.visible)
	for path: String in NODE_TYPES:
		var node: Node = _nodes[path]
		if node is Control:
			var control: Control = node as Control
			var blocks: bool = node == panel or node is Button or node is ScrollContainer
			_record_property(undo, node, &"mouse_filter", Control.MOUSE_FILTER_STOP if blocks else Control.MOUSE_FILTER_IGNORE, control.mouse_filter)
		if node is Label and (node as Label).text.is_empty():
			_record_property(undo, node, &"text", _preview_text(String(node.name)), (node as Label).text)
		if node is Button:
			var button: Button = node as Button
			if button.text.is_empty():
				_record_property(undo, node, &"text", _preview_text(String(node.name)), button.text)
			if String(node.name) in ["SugarcaneButton", "RiceButton", "CornButton", "RemoveButton", "TransferButton"]:
				_record_property(undo, node, &"toggle_mode", true, button.toggle_mode)
	# An empty action is harmless; it does not replace nodes or reset styles.
	undo.commit_action()
	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(panel)
	EditorInterface.edit_node(panel)
	if _changed:
		print("HUD and inspector baked and wired. Save the scene with Ctrl+S. Disease Database is optional.")
	else:
		print("Tile inspector is already built and wired; no nodes were duplicated.")
	# Ownership of created nodes has transferred to the scene/undo history.
	_created.clear()
	_created_parents.clear()
	_nodes.clear()


## Preflight everything before touching the open scene.
## Missing nodes are staged, existing compatible nodes are reused.
func _prepare(scene_root: Node) -> bool:
	_nodes.clear()
	_created.clear()
	_created_parents.clear()
	for path: String in NODE_TYPES:
		var node: Node = scene_root.get_node_or_null(NodePath(path))
		if node != null:
			if not node.is_class(NODE_TYPES[path]):
				return _abort("%s must be a %s. Existing nodes were left untouched." % [path, NODE_TYPES[path]])
			if not node.scene_file_path.is_empty() or (node.owner != null and node.owner != scene_root):
				return _abort("%s belongs to a nested scene. Make a local inspector before using this builder." % path)
			if path == String(PANEL_PATH):
				var script: Script = node.get_script() as Script
				if script != null and script != VIEW_SCRIPT:
					return _abort("TileInspectorPanel already has a different script. No changes were made.")
		else:
			node = ClassDB.instantiate(NODE_TYPES[path]) as Node
			if node == null:
				return _abort("Could not instantiate %s." % NODE_TYPES[path])
			node.name = StringName(path.get_file())
			var parent_path: String = path.get_base_dir()
			var parent: Node = scene_root if parent_path.is_empty() else _nodes.get(parent_path) as Node
			if parent == null:
				node.free()
				return _abort("Missing parent for %s." % path)
			_configure_new_node(node)
			_created.append(node)
			_created_parents.append(parent)
		_nodes[path] = node
	return true


func _record_property(
	undo: EditorUndoRedoManager,
	target: Object,
	property_name: StringName,
	value: Variant,
	previous_value: Variant
) -> void:
	if value == previous_value:
		return
	undo.add_do_property(target, property_name, value)
	undo.add_undo_property(target, property_name, previous_value)
	_changed = true


func _configure_new_node(node: Node) -> void:
	if node is Control:
		var control: Control = node as Control
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if node is PanelContainer:
		var panel: PanelContainer = node as PanelContainer
		panel.size = Vector2(340.0, 560.0)
		panel.position = Vector2(800.0, 12.0)
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.show()
		if node.name == &"Panel":
			panel.position = Vector2(12.0, 12.0)
			panel.size = Vector2(360.0, 240.0)
	elif node is MarginContainer:
		var margin: MarginContainer = node as MarginContainer
		for side: String in ["left", "right", "top", "bottom"]:
			margin.add_theme_constant_override("margin_" + side, 12)
	elif node is ScrollContainer:
		var scroll: ScrollContainer = node as ScrollContainer
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		scroll.mouse_filter = Control.MOUSE_FILTER_STOP
		scroll.mouse_force_pass_scroll_events = false
	elif node is GridContainer:
		(node as GridContainer).columns = 2
	elif node is OptionButton:
		var selector: OptionButton = node as OptionButton
		for caption: String in ["Disease Default", "Spatial SIR", "Spatial SEIR", "Stochastic CA-SIR"]:
			selector.add_item(caption)
		selector.mouse_filter = Control.MOUSE_FILTER_STOP
		selector.custom_minimum_size = Vector2(160.0, 44.0)
	elif node is Button:
		var button: Button = node as Button
		button.text = _preview_text(String(node.name))
		button.custom_minimum_size = Vector2(64.0, 44.0)
		button.size_flags_horizontal = Control.SIZE_SHRINK_END
		button.mouse_filter = Control.MOUSE_FILTER_STOP
	elif node is ProgressBar:
		var bar: ProgressBar = node as ProgressBar
		bar.min_value = 0.0
		bar.max_value = 100.0
		bar.step = 0.1
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(96.0, 16.0)
	elif node is Label:
		var label: Label = node as Label
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		match String(node.name):
			"TitleLabel":
				label.text = "Tile inspector"
			"TerrainHeading":
				label.text = "Terrain & soil"
			"CropHeading":
				label.text = "Crop"
			"EpidemicHeading":
				label.text = "Epidemic state"
			"FractionsHeading":
				label.text = "Compartment fractions"


func _abort(message: String) -> bool:
	# Staged nodes are detached; no existing scene objects are freed.
	for node: Node in _created:
		node.free()
	_created.clear()
	_created_parents.clear()
	_nodes.clear()
	push_error(message)
	return false



func _preview_text(node_name: String) -> String:
	match node_name:
		"SugarcaneButton": return "Sugarcane"
		"RiceButton": return "Rice"
		"CornButton": return "Corn"
		"RemoveButton": return "Shovel"
		"TransferButton": return "Move"
		"NextTurnButton": return "Next Turn"
		"CloseButton": return "Close"
		"SeedInfectionButton": return "Seed Infection"
		"TurnLabel": return "Turn: 0"
		"SelectedCropLabel": return "Mode: Inspect"
		"StatusLabel": return "Click a tile to inspect it."
		"TitleLabel": return "Tile inspector"
	return node_name.trim_suffix("Label").capitalize() + ": --"
