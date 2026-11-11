@tool
extends EditorPlugin


func _enter_tree() -> void:
	if OS.get_environment("GODOT_DRAFT_DISEASE_PLAYTEST_SETUP") == "1":
		_run_draft_disease_playtest_setup.call_deferred()
		return
	if OS.get_environment("GODOT_CATALOG_SETUP") == "1":
		_run_catalog_setup.call_deferred()
		return
	if OS.get_environment("GODOT_ACTIVATION_SETUP") == "1":
		_run_activation_setup.call_deferred()
		return
	if OS.get_environment("GODOT_SHADOW_SETUP") == "1":
		_run_shadow_setup.call_deferred()
		return
	if OS.get_environment("GODOT_LIGHTING_SETUP") == "1":
		_run_lighting_setup.call_deferred()
		return
	if OS.get_environment("GODOT_MANUAL_WORLD_SETUP") == "1":
		_run_manual_world_setup.call_deferred()
		return
	if OS.get_environment("GODOT_FIELD_TOOLS_SETUP") == "1":
		_run_field_tools_setup.call_deferred()
		return
	if OS.get_environment("GODOT_FENCE_TOOL_SETUP") == "1":
		_run_fence_tool_setup.call_deferred()
		return
	if OS.get_environment("GODOT_FENCE_AUTOTILE_SETUP") == "1":
		_run_fence_autotile_setup.call_deferred()
		return
	if OS.get_environment("GODOT_CROP_VISUAL_SETUP") == "1":
		_run_crop_setup.call_deferred()
		return
	if OS.get_environment("GODOT_PLAYTEST_SETUP") == "1":
		_run_setup.call_deferred()
		return
	if OS.get_environment("GODOT_EDITOR_TEST") in ["tile_inspector_builder", "terrain_preview"]:
		_run_test.call_deferred()


func _run_test() -> void:
	var test_path: String = "res://tests/presentation/terrain_preview_editor_test.gd" if OS.get_environment("GODOT_EDITOR_TEST") == "terrain_preview" else "res://tests/presentation/tile_inspector_builder_editor_test.gd"
	var test_script: Script = load(test_path) as Script
	var test: RefCounted = test_script.new() as RefCounted
	var result: int = await test.run(get_tree())
	test = null
	# Quit the real editor SceneTree, allowing its normal teardown to run.
	get_tree().quit(result)


func _run_activation_setup() -> void:
	var setup: EditorScript = (load("res://tools/setup_disease_activation.gd") as Script).new() as EditorScript
	var result: int = await setup.run_setup()
	setup = null
	get_tree().quit(result)


func _run_catalog_setup() -> void:
	var setup: EditorScript = (load("res://tools/setup_disease_catalog.gd") as Script).new() as EditorScript
	var result: int = await setup.run_setup()
	setup = null
	get_tree().quit(result)


func _run_draft_disease_playtest_setup() -> void:
	var setup: EditorScript = (load("res://tools/enable_draft_disease_playtest.gd") as Script).new() as EditorScript
	var result: int = await setup.run_setup()
	setup = null
	get_tree().quit(result)


func _run_lighting_setup() -> void:
	var setup: EditorScript = (load("res://tools/setup_world_lighting.gd") as Script).new() as EditorScript
	var result: int = await setup.run_setup()
	setup = null
	get_tree().quit(result)


func _run_shadow_setup() -> void:
	var setup: EditorScript = (load("res://tools/setup_scenery_shadows.gd") as Script).new() as EditorScript
	var result: int = await setup.run_setup()
	setup = null
	get_tree().quit(result)


func _run_manual_world_setup() -> void:
	var setup_script: Script = load("res://tools/setup_manual_world.gd") as Script
	var setup: EditorScript = setup_script.new() as EditorScript
	var result: int = await setup.run_setup()
	setup = null
	get_tree().quit(result)


func _run_setup() -> void:
	var setup_script: Script = load("res://tools/setup_disease_playtest.gd") as Script
	var setup: EditorScript = setup_script.new() as EditorScript
	var result: int = await setup.run_setup()
	setup = null
	get_tree().quit(result)


func _run_crop_setup() -> void:
	var setup_script: Script = load("res://tools/setup_crop_growth_visuals.gd") as Script
	var setup: EditorScript = setup_script.new() as EditorScript
	var result: int = await setup.run_setup()
	setup = null
	get_tree().quit(result)


func _run_field_tools_setup() -> void:
	var setup_script: Script = load("res://tools/setup_field_tools.gd") as Script
	var setup: EditorScript = setup_script.new() as EditorScript
	var result: int = await setup.run_setup()
	setup = null
	get_tree().quit(result)


func _run_fence_tool_setup() -> void:
	var setup_script: Script = load("res://tools/setup_fence_tool.gd") as Script
	var setup: EditorScript = setup_script.new() as EditorScript
	var result: int = await setup.run_setup()
	setup = null
	get_tree().quit(result)


func _run_fence_autotile_setup() -> void:
	var setup_script: Script = load("res://tools/setup_fence_tool.gd") as Script
	var setup: EditorScript = setup_script.new() as EditorScript
	var result: int = await setup.run_setup()
	setup = null
	get_tree().quit(result)
