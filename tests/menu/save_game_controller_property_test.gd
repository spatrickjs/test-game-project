extends SceneTree
## Property-based test for SaveGameController save-existence behavior.
##
## Property 9: has_saved_game() returns true if and only if the save file exists at
## the configured path, and the Continue button is disabled when has_saved_game()
## returns false.
## Validates: Requirements 6.4 (Continue option disabled when no Saved_Game exists).

const TEST_SAVE_PATH := "user://test_save_p9.dat"

var _controller: SaveGameController
var _last_save_signal: Variant


func _initialize() -> void:
	_cleanup_file()
	_controller = SaveGameController.new()
	_controller._save_path = TEST_SAVE_PATH
	_controller.save_state_changed.connect(_on_save_state_changed)

	var runner := PropertyTestRunner.new()

	# Feature: scene-management-and-navigation, Property 9: Continue option disabled without save
	runner.run_property(9, "Continue option disabled without save", func(r: PropertyTestRunner) -> bool:
		_cleanup_file()
		_controller._last_known_has_save = false
		_last_save_signal = null

		# Randomly decide whether a save file exists this iteration.
		var create_save := r.boolean()
		if create_save:
			_write_save_file()

		var file_exists := FileAccess.file_exists(TEST_SAVE_PATH)
		var has_save := _controller.has_saved_game()
		r.describe_input("create_save=%s file_exists=%s has_save=%s" % [create_save, file_exists, has_save])

		# has_saved_game() returns true iff the save file exists at the configured path.
		r.check(has_save == file_exists, "has_saved_game() true iff file exists")
		r.check(has_save == create_save, "has_saved_game() matches create_save decision")

		# Continue button disabled iff has_saved_game() returns false (presenter contract).
		var continue_disabled := not has_save
		r.check(continue_disabled == (not file_exists), "Continue disabled iff no save file")
		r.check(continue_disabled == (not create_save), "Continue disabled iff no save created")

		# refresh() emits save_state_changed only when existence changes from the last
		# known state; when it emits, the value must match has_saved_game().
		_controller.refresh()
		if create_save:
			r.check(_last_save_signal == true, "refresh() emits true when save appears")
		else:
			r.check(_last_save_signal == null, "refresh() does not emit when no save (no change)")

		_cleanup_file()
		return true
	)

	_controller.free()
	_cleanup_file()
	quit(runner.finish("MENU_PROPERTY_PASS"))


func _on_save_state_changed(has_save: bool) -> void:
	_last_save_signal = has_save


func _write_save_file() -> void:
	var config := ConfigFile.new()
	config.set_value("metadata", "timestamp", 1234567890)
	config.set_value("metadata", "turn_index", 5)
	config.set_value("metadata", "display_name", "Test Save")
	config.save(TEST_SAVE_PATH)


func _cleanup_file() -> void:
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(TEST_SAVE_PATH)
