extends RefCounted
## Builds an in-memory inspector fixture only; no scene/resource files are saved.


static func create() -> TileInspectorView:
	var view: TileInspectorView = TileInspectorView.new()
	view.name = "TileInspectorPanel"
	var margin: MarginContainer = MarginContainer.new()
	view.add_child(margin)
	var layout: VBoxContainer = VBoxContainer.new()
	margin.add_child(layout)
	var header: HBoxContainer = HBoxContainer.new()
	layout.add_child(header)
	view.title_label = _label(header)
	view.close_button = Button.new()
	header.add_child(view.close_button)
	view.scroll_container = ScrollContainer.new()
	layout.add_child(view.scroll_container)
	var content: VBoxContainer = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.scroll_container.add_child(content)
	view.terrain_label = _label(content)
	view.soil_ph_label = _label(content)
	view.macronutrients_label = _label(content)
	view.crop_name_label = _label(content)
	view.growth_label = _label(content)
	view.disease_label = _label(content)
	view.state_label = _label(content)
	view.removed_outcome_label = _label(content)
	view.susceptible_label = _label(content)
	view.exposed_label = _label(content)
	view.infected_label = _label(content)
	view.immune_label = _label(content)
	view.dead_label = _label(content)
	view.growth_bar = ProgressBar.new()
	content.add_child(view.growth_bar)
	view.susceptible_bar = ProgressBar.new()
	content.add_child(view.susceptible_bar)
	view.exposed_bar = ProgressBar.new()
	content.add_child(view.exposed_bar)
	view.infected_bar = ProgressBar.new()
	content.add_child(view.infected_bar)
	view.immune_bar = ProgressBar.new()
	content.add_child(view.immune_bar)
	view.dead_bar = ProgressBar.new()
	content.add_child(view.dead_bar)
	return view


static func _label(parent: Node) -> Label:
	var label: Label = Label.new()
	parent.add_child(label)
	return label
