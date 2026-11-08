class_name SettingsState
extends RefCounted
## Working or saved settings values organized by Settings_Panel tab.
## Logic owns and mutates these instances; Presentation treats them as read-only.
## Used by SettingsController for dirty tracking, save, and revert.

const VOLUME_EQUALITY_TOLERANCE: float = 0.00001

# Sound tab
var master_volume: float = 1.0
var music_volume: float = 0.8
var sfx_volume: float = 0.8

# Graphics tab
var graphics_quality: NavigationEnums.GraphicsQuality = NavigationEnums.GraphicsQuality.MEDIUM
var fullscreen: bool = false
var vsync: bool = true

# Difficulty tab
var difficulty: NavigationEnums.Difficulty = NavigationEnums.Difficulty.NORMAL


## Reports invalid values without mutating this instance.
func validate() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	_validate_volume("master_volume", master_volume, errors)
	_validate_volume("music_volume", music_volume, errors)
	_validate_volume("sfx_volume", sfx_volume, errors)
	if not NavigationEnums.GraphicsQuality.values().has(graphics_quality):
		errors.append("graphics_quality has an invalid identifier.")
	if not NavigationEnums.Difficulty.values().has(difficulty):
		errors.append("difficulty has an invalid identifier.")
	return errors


## Compares all fields. Returns false when other is null or differs in any field.
## Volumes use a tolerance so serialization round trips do not report spurious differences.
func equals(other: SettingsState) -> bool:
	if other == null:
		return false
	if absf(master_volume - other.master_volume) > VOLUME_EQUALITY_TOLERANCE:
		return false
	if absf(music_volume - other.music_volume) > VOLUME_EQUALITY_TOLERANCE:
		return false
	if absf(sfx_volume - other.sfx_volume) > VOLUME_EQUALITY_TOLERANCE:
		return false
	if graphics_quality != other.graphics_quality:
		return false
	if fullscreen != other.fullscreen:
		return false
	if vsync != other.vsync:
		return false
	if difficulty != other.difficulty:
		return false
	return true


## Deep-copies all settings values, including invalid values, without sharing state.
func copy() -> SettingsState:
	var result: SettingsState = SettingsState.new()
	result.master_volume = master_volume
	result.music_volume = music_volume
	result.sfx_volume = sfx_volume
	result.graphics_quality = graphics_quality
	result.fullscreen = fullscreen
	result.vsync = vsync
	result.difficulty = difficulty
	return result


func _validate_volume(
	property_name: String,
	value: float,
	errors: PackedStringArray
) -> void:
	if is_nan(value) or is_inf(value):
		errors.append("%s must be finite." % property_name)
	elif value < 0.0 or value > 1.0:
		errors.append("%s must be in [0.0, 1.0]." % property_name)
