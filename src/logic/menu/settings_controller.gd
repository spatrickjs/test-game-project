class_name SettingsController
extends Node
## Owns the working and last-persisted SettingsState and drives the save/revert
## lifecycle for the Settings_Panel. Presentation never mutates state directly; it
## calls set_value, save, and revert here and reads values back via get_value. Dirty
## tracking compares the working state against the saved state, so revert and
## save-confirm semantics stay consistent without duplicating field knowledge.
## Settings are persisted to user://settings.cfg via ConfigFile; enum values are
## stored as integers for forward-compatibility, matching simulation_enums.gd.

signal dirty_changed(is_dirty: bool)
signal saved()
signal load_failed(reason: String)

## Working (potentially unsaved) values. Presentation reads via get_value.
var state: SettingsState = SettingsState.new()
## Last-persisted snapshot, used for dirty comparison and revert.
var _saved_state: SettingsState = SettingsState.new()
## ConfigFile destination. Override for tests via set_config_path.
var _config_path: String = "user://settings.cfg"

var last_error: String = ""
var _dirty: bool = false


## Reads user://settings.cfg. On first launch (file missing) loads defaults and
## returns true. On a corrupt or unreadable file emits load_failed, falls back to
## defaults, and returns false. Missing sections fall back to per-section defaults
## via ConfigFile.get_value fallbacks.
func load_settings() -> bool:
	last_error = ""
	if not FileAccess.file_exists(_config_path):
		_apply_defaults()
		return true
	var config := ConfigFile.new()
	var err: int = config.load(_config_path)
	if err != OK:
		var reason := "Could not parse settings file (error %d)." % err
		last_error = reason
		load_failed.emit(reason)
		_apply_defaults()
		return false
	var loaded := _config_to_state(config)
	var errors := loaded.validate()
	if not errors.is_empty():
		var reason := "Settings file has invalid values: %s" % "\n".join(errors)
		last_error = reason
		load_failed.emit(reason)
		_apply_defaults()
		return false
	state = loaded
	_saved_state = loaded.copy()
	_dirty = false
	return true


## Updates a single working value. Validates the proposed value against the full
## state before committing: an invalid value is rejected without mutating state or
## the dirty flag. Emits dirty_changed only when the dirty state actually transitions,
## so reverting the last modified field back to its saved value reports clean again.
func set_value(category: NavigationEnums.SettingsTab, key: String, value: Variant) -> void:
	var candidate := state.copy()
	if not _apply_value(candidate, category, key, value):
		return
	var errors := candidate.validate()
	if not errors.is_empty():
		last_error = "\n".join(errors)
		return
	state = candidate
	last_error = ""
	_refresh_dirty()


## Serializes the working state to user://settings.cfg, copies it into _saved_state,
## emits saved, then clears dirty. Returns false and sets last_error on write failure
## while preserving the dirty state so the player can retry. State validity is
## enforced at set_value, so save never persists invalid values.
func save() -> bool:
	last_error = ""
	var config := ConfigFile.new()
	_state_to_config(config, state)
	var err: int = config.save(_config_path)
	if err != OK:
		last_error = "Could not write settings file (error %d)." % err
		return false
	_saved_state = state.copy()
	saved.emit()
	_set_dirty(false)
	return true


## Restores the working state to the last-persisted snapshot and clears dirty.
func revert() -> void:
	last_error = ""
	state = _saved_state.copy()
	_set_dirty(false)


## True when the working state differs from the saved state in any field.
func is_dirty() -> bool:
	return not state.equals(_saved_state)


## Returns the current (working) value for a category/key, or null when unknown.
func get_value(category: NavigationEnums.SettingsTab, key: String) -> Variant:
	match category:
		NavigationEnums.SettingsTab.SOUND:
			match key:
				"master_volume": return state.master_volume
				"music_volume": return state.music_volume
				"sfx_volume": return state.sfx_volume
		NavigationEnums.SettingsTab.GRAPHICS:
			match key:
				"graphics_quality": return state.graphics_quality
				"fullscreen": return state.fullscreen
				"vsync": return state.vsync
		NavigationEnums.SettingsTab.DIFFICULTY:
			match key:
				"difficulty": return state.difficulty
	last_error = "Unknown setting %s/%s." % [
		NavigationEnums.SettingsTab.find_key(category),
		key,
	]
	return null


## Allows tests to redirect persistence to a temp path without touching user://.
func set_config_path(path: String) -> void:
	_config_path = path


## Writes all settings fields into a ConfigFile. Enum values are stored as integers.
func _state_to_config(config: ConfigFile, source: SettingsState) -> void:
	config.set_value("sound", "master_volume", source.master_volume)
	config.set_value("sound", "music_volume", source.music_volume)
	config.set_value("sound", "sfx_volume", source.sfx_volume)
	config.set_value("graphics", "graphics_quality", int(source.graphics_quality))
	config.set_value("graphics", "fullscreen", source.fullscreen)
	config.set_value("graphics", "vsync", source.vsync)
	config.set_value("difficulty", "difficulty", int(source.difficulty))


## Reads all settings fields from a ConfigFile, applying per-key defaults so missing
## sections fall back gracefully. Type constructors coerce ConfigFile Variants.
func _config_to_state(config: ConfigFile) -> SettingsState:
	var defaults := SettingsState.new()
	var result := SettingsState.new()
	result.master_volume = float(config.get_value("sound", "master_volume", defaults.master_volume))
	result.music_volume = float(config.get_value("sound", "music_volume", defaults.music_volume))
	result.sfx_volume = float(config.get_value("sound", "sfx_volume", defaults.sfx_volume))
	result.graphics_quality = int(config.get_value("graphics", "graphics_quality", defaults.graphics_quality))
	result.fullscreen = bool(config.get_value("graphics", "fullscreen", defaults.fullscreen))
	result.vsync = bool(config.get_value("graphics", "vsync", defaults.vsync))
	result.difficulty = int(config.get_value("difficulty", "difficulty", defaults.difficulty))
	return result


## Applies a single value to the target state with type checking. Returns false and
## sets last_error when the category/key is unknown or the value type is wrong. Range
## and enum-value validity are checked separately by SettingsState.validate().
func _apply_value(
	target: SettingsState,
	category: NavigationEnums.SettingsTab,
	key: String,
	value: Variant
) -> bool:
	match category:
		NavigationEnums.SettingsTab.SOUND:
			match key:
				"master_volume":
					if not _is_real(value):
						return _reject_type(key, "number", value)
					target.master_volume = float(value)
				"music_volume":
					if not _is_real(value):
						return _reject_type(key, "number", value)
					target.music_volume = float(value)
				"sfx_volume":
					if not _is_real(value):
						return _reject_type(key, "number", value)
					target.sfx_volume = float(value)
				_:
					return _reject_key(category, key)
		NavigationEnums.SettingsTab.GRAPHICS:
			match key:
				"graphics_quality":
					if not (value is int):
						return _reject_type(key, "integer", value)
					target.graphics_quality = value
				"fullscreen":
					if not (value is bool):
						return _reject_type(key, "boolean", value)
					target.fullscreen = value
				"vsync":
					if not (value is bool):
						return _reject_type(key, "boolean", value)
					target.vsync = value
				_:
					return _reject_key(category, key)
		NavigationEnums.SettingsTab.DIFFICULTY:
			match key:
				"difficulty":
					if not (value is int):
						return _reject_type(key, "integer", value)
					target.difficulty = value
				_:
					return _reject_key(category, key)
		_:
			last_error = "Unknown settings category: %s." % NavigationEnums.SettingsTab.find_key(category)
			return false
	return true


## Resets state and _saved_state to independent default instances and clears dirty.
func _apply_defaults() -> void:
	state = SettingsState.new()
	_saved_state = state.copy()
	_dirty = false


## Recomputes dirty from the current state and emits dirty_changed on transition.
func _refresh_dirty() -> void:
	_set_dirty(not state.equals(_saved_state))


## Emits dirty_changed only when the dirty state actually changes.
func _set_dirty(value: bool) -> void:
	if _dirty != value:
		_dirty = value
		dirty_changed.emit(_dirty)


func _is_real(value: Variant) -> bool:
	return value is float or value is int


func _reject_type(key: String, expected: String, value: Variant) -> bool:
	last_error = "%s expects a %s, got %s." % [key, expected, type_string(typeof(value))]
	return false


func _reject_key(category: NavigationEnums.SettingsTab, key: String) -> bool:
	last_error = "Unknown setting %s/%s." % [NavigationEnums.SettingsTab.find_key(category), key]
	return false
