@tool
extends EditorPlugin


func _enter_tree() -> void:
	if OS.get_environment("GODOT_PLAYTEST_SETUP") == "1":
		_run_setup.call_deferred()
		return
	if OS.get_environment("GODOT_EDITOR_TEST") == "tile_inspector_builder":
		_run_test.call_deferred()


func _run_test() -> void:
	var test_script: Script = load("res://tests/presentation/tile_inspector_builder_editor_test.gd") as Script
	var test: RefCounted = test_script.new() as RefCounted
	var result: int = await test.run(get_tree())
	test = null
	# Quit the real editor SceneTree, allowing its normal teardown to run.
	get_tree().quit(result)


func _run_setup() -> void:
	var setup_script: Script = load("res://tools/setup_disease_playtest.gd") as Script
	var setup: EditorScript = setup_script.new() as EditorScript
	var result: int = await setup.run_setup()
	setup = null
	get_tree().quit(result)
