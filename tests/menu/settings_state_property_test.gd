extends SceneTree
## Property-based tests for SettingsController save/revert/dirty lifecycle.
##
## Uses PropertyTestRunner for randomized input generation (minimum 100 iterations
## per property). Each property references its design-document correctness property
## via a traceability tag comment above the run_property() call.
##
## Validates: Requirements 3.1 (save persists changes + confirmation),
## 3.4 (save confirmation clears unsaved changes).

func _initialize() -> void:
	var runner := PropertyTestRunner.new()

	# Feature: scene-management-and-navigation, Property 1: Settings save clears dirty state
	runner.run_property(1, "Settings save clears dirty state", func(r: PropertyTestRunner) -> bool:
		# Fresh controller per iteration, redirected to a temp config path.
		var ctrl := SettingsController.new()
		var config_path := "user://test_settings_p1.cfg"
		DirAccess.remove_absolute(config_path)
		ctrl.set_config_path(config_path)
		ctrl.load_settings()

		# Generate randomized valid values for every settings field.
		var master_vol := r.volume()
		var music_vol := r.volume()
		var sfx_vol := r.volume()
		var gq: int = r.graphics_quality()
		var fs := r.boolean()
		var vs := r.boolean()
		var diff: int = r.difficulty()
		r.describe_input("master=%.4f music=%.4f sfx=%.4f gq=%d fullscreen=%d vsync=%d difficulty=%d" % [
			master_vol, music_vol, sfx_vol, gq, int(fs), int(vs), diff])

		# Apply all values via set_value (validates each before committing).
		ctrl.set_value(NavigationEnums.SettingsTab.SOUND, "master_volume", master_vol)
		ctrl.set_value(NavigationEnums.SettingsTab.SOUND, "music_volume", music_vol)
		ctrl.set_value(NavigationEnums.SettingsTab.SOUND, "sfx_volume", sfx_vol)
		ctrl.set_value(NavigationEnums.SettingsTab.GRAPHICS, "graphics_quality", gq)
		ctrl.set_value(NavigationEnums.SettingsTab.GRAPHICS, "fullscreen", fs)
		ctrl.set_value(NavigationEnums.SettingsTab.GRAPHICS, "vsync", vs)
		ctrl.set_value(NavigationEnums.SettingsTab.DIFFICULTY, "difficulty", diff)

		# Precondition: at least one field must differ from the saved (default) state.
		# When all random values happen to match defaults, force master_volume to 0.0
		# (default is 1.0, so this is guaranteed to differ).
		if not ctrl.is_dirty():
			ctrl.set_value(NavigationEnums.SettingsTab.SOUND, "master_volume", 0.0)

		r.check(ctrl.is_dirty(), "Precondition: is_dirty() must be true before save")

		# Exercise: save() persists the working state to disk.
		var save_ok := ctrl.save()
		r.check(save_ok, "save() should succeed")

		# Property 1a: is_dirty() SHALL return false after save.
		r.check(not ctrl.is_dirty(), "is_dirty() must be false after save()")

		# Property 1b: working state SHALL equal the saved state after save.
		r.check(ctrl.state.equals(ctrl._saved_state), "working state must equal saved state after save()")

		# Clean up temp file and controller.
		DirAccess.remove_absolute(config_path)
		ctrl.free()
		return true
	)

	quit(runner.finish("MENU_PROPERTY_PASS"))
