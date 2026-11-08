extends SceneTree
## Unit tests for SettingsState validation, copy independence, and equality.
## Validates: Requirements 2.2 (Sound tab volume controls), 2.3 (Graphics tab controls),
## 2.4 (Difficulty tab selection controls).

var _failures: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	_test_validate_defaults()
	_test_validate_volume_bounds()
	_test_validate_invalid_enums()
	_test_validate_does_not_mutate()
	_test_copy_preserves_values()
	_test_copy_independence()
	_test_equals_identical()
	_test_equals_copy()
	_test_equals_field_differences()
	_test_equals_null()
	_finish()


# --- validate() ----------------------------------------------------------

func _test_validate_defaults() -> void:
	var state := SettingsState.new()
	_check(state.validate().is_empty(), "Default state validates clean")


func _test_validate_volume_bounds() -> void:
	# Below range
	var state := SettingsState.new()
	state.master_volume = -0.1
	_check(not state.validate().is_empty(), "Below-range master_volume flagged")

	# Above range
	state = SettingsState.new()
	state.music_volume = 1.1
	_check(not state.validate().is_empty(), "Above-range music_volume flagged")

	# NaN
	state = SettingsState.new()
	state.sfx_volume = NAN
	_check(not state.validate().is_empty(), "NaN sfx_volume flagged")

	# Infinity
	state = SettingsState.new()
	state.master_volume = INF
	_check(not state.validate().is_empty(), "Inf master_volume flagged")

	# Boundary values 0.0 and 1.0 are inclusive and valid.
	state = SettingsState.new()
	state.master_volume = 0.0
	state.music_volume = 1.0
	state.sfx_volume = 0.5
	_check(state.validate().is_empty(), "Boundary volumes validate clean")


func _test_validate_invalid_enums() -> void:
	var state := SettingsState.new()
	state.set("graphics_quality", 99)
	_check(not state.validate().is_empty(), "Invalid graphics_quality flagged")

	state = SettingsState.new()
	state.set("difficulty", 99)
	_check(not state.validate().is_empty(), "Invalid difficulty flagged")


func _test_validate_does_not_mutate() -> void:
	var state := SettingsState.new()
	state.master_volume = -0.5
	state.set("difficulty", 99)
	var volume_before := state.master_volume
	var difficulty_before: int = state.difficulty
	state.validate()
	_check(state.master_volume == volume_before, "validate() does not mutate master_volume")
	_check(state.difficulty == difficulty_before, "validate() does not mutate difficulty")


# --- copy() --------------------------------------------------------------

func _test_copy_preserves_values() -> void:
	var original := SettingsState.new()
	original.master_volume = 0.3
	original.music_volume = 0.6
	original.sfx_volume = 0.9
	original.graphics_quality = NavigationEnums.GraphicsQuality.HIGH
	original.fullscreen = true
	original.vsync = false
	original.difficulty = NavigationEnums.Difficulty.HARD
	var copy := original.copy()
	_check(copy.master_volume == 0.3, "Copy preserves master_volume")
	_check(copy.music_volume == 0.6, "Copy preserves music_volume")
	_check(copy.sfx_volume == 0.9, "Copy preserves sfx_volume")
	_check(copy.graphics_quality == NavigationEnums.GraphicsQuality.HIGH, "Copy preserves graphics_quality")
	_check(copy.fullscreen == true, "Copy preserves fullscreen")
	_check(copy.vsync == false, "Copy preserves vsync")
	_check(copy.difficulty == NavigationEnums.Difficulty.HARD, "Copy preserves difficulty")


func _test_copy_independence() -> void:
	var original := SettingsState.new()
	original.master_volume = 0.4
	original.graphics_quality = NavigationEnums.GraphicsQuality.HIGH
	original.difficulty = NavigationEnums.Difficulty.HARD
	var copy := original.copy()

	# Mutating the copy must not affect the original.
	copy.master_volume = 0.9
	copy.graphics_quality = NavigationEnums.GraphicsQuality.LOW
	copy.difficulty = NavigationEnums.Difficulty.EASY
	copy.fullscreen = true
	_check(original.master_volume == 0.4, "Original master_volume unchanged after copy mutation")
	_check(original.graphics_quality == NavigationEnums.GraphicsQuality.HIGH, "Original graphics_quality unchanged after copy mutation")
	_check(original.difficulty == NavigationEnums.Difficulty.HARD, "Original difficulty unchanged after copy mutation")
	_check(original.fullscreen == false, "Original fullscreen unchanged after copy mutation")

	# Mutating the original must not affect the copy.
	original.music_volume = 0.1
	original.vsync = false
	_check(copy.music_volume == 0.8, "Copy music_volume unchanged after original mutation")
	_check(copy.vsync == true, "Copy vsync unchanged after original mutation")


# --- equals() ------------------------------------------------------------

func _test_equals_identical() -> void:
	var a := SettingsState.new()
	var b := SettingsState.new()
	_check(a.equals(b), "Two default states are equal")

	a.master_volume = 0.5
	b.master_volume = 0.5
	a.graphics_quality = NavigationEnums.GraphicsQuality.LOW
	b.graphics_quality = NavigationEnums.GraphicsQuality.LOW
	a.difficulty = NavigationEnums.Difficulty.EASY
	b.difficulty = NavigationEnums.Difficulty.EASY
	_check(a.equals(b), "States with identical values are equal")


func _test_equals_copy() -> void:
	var state := SettingsState.new()
	state.master_volume = 0.7
	state.graphics_quality = NavigationEnums.GraphicsQuality.HIGH
	state.fullscreen = true
	state.difficulty = NavigationEnums.Difficulty.HARD
	_check(state.equals(state.copy()), "State equals its own copy")


func _test_equals_field_differences() -> void:
	# Differ in master_volume
	var a := SettingsState.new()
	var b := SettingsState.new()
	a.master_volume = 0.5
	b.master_volume = 0.6
	_check(not a.equals(b), "Different master_volume not equal")

	# Differ in music_volume
	a = SettingsState.new()
	b = SettingsState.new()
	a.music_volume = 0.5
	b.music_volume = 0.6
	_check(not a.equals(b), "Different music_volume not equal")

	# Differ in sfx_volume
	a = SettingsState.new()
	b = SettingsState.new()
	a.sfx_volume = 0.5
	b.sfx_volume = 0.6
	_check(not a.equals(b), "Different sfx_volume not equal")

	# Differ in graphics_quality
	a = SettingsState.new()
	b = SettingsState.new()
	a.graphics_quality = NavigationEnums.GraphicsQuality.HIGH
	b.graphics_quality = NavigationEnums.GraphicsQuality.LOW
	_check(not a.equals(b), "Different graphics_quality not equal")

	# Differ in fullscreen
	a = SettingsState.new()
	b = SettingsState.new()
	a.fullscreen = true
	b.fullscreen = false
	_check(not a.equals(b), "Different fullscreen not equal")

	# Differ in vsync
	a = SettingsState.new()
	b = SettingsState.new()
	a.vsync = false
	b.vsync = true
	_check(not a.equals(b), "Different vsync not equal")

	# Differ in difficulty
	a = SettingsState.new()
	b = SettingsState.new()
	a.difficulty = NavigationEnums.Difficulty.HARD
	b.difficulty = NavigationEnums.Difficulty.EASY
	_check(not a.equals(b), "Different difficulty not equal")


func _test_equals_null() -> void:
	var state := SettingsState.new()
	_check(not state.equals(null), "Equals null returns false")


# --- Helpers -------------------------------------------------------------

func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)


func _finish() -> void:
	if _failures.is_empty():
		print("MENU_SETTINGS_STATE_UNIT_PASS")
		quit(0)
	else:
		for failure: String in _failures:
			printerr("FAIL: " + failure)
		quit(1)
