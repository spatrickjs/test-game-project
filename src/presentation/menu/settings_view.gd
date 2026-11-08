class_name SettingsView
extends Control
## Settings panel with Sound, Graphics, and Difficulty tabs.
## Forwards tab switches and control changes as signals; owns no settings state.
## The presenter routes setting_changed to SettingsController.set_value and
## toggles visibility in response to NavigationController.screen_changed.

signal sound_tab_selected
signal graphics_tab_selected
signal difficulty_tab_selected
signal save_pressed
signal exit_pressed
signal setting_changed(tab: NavigationEnums.SettingsTab, key: String, value: Variant)

## Setting key identifiers, matching the ConfigFile sections in SettingsState.
const KEY_MASTER_VOLUME := "master_volume"
const KEY_MUSIC_VOLUME := "music_volume"
const KEY_SFX_VOLUME := "sfx_volume"
const KEY_GRAPHICS_QUALITY := "graphics_quality"
const KEY_FULLSCREEN := "fullscreen"
const KEY_VSYNC := "vsync"
const KEY_DIFFICULTY := "difficulty"

## Display labels for option-button items, ordered to match enum numeric values.
const GRAPHICS_QUALITY_LABELS: PackedStringArray = ["Low", "Medium", "High"]
const DIFFICULTY_LABELS: PackedStringArray = ["Easy", "Normal", "Hard"]

@export_group("Structure")
## Hosts the three settings tabs. Tab order must match SettingsTab enum values.
@export var tab_container: TabContainer
## Persists the working settings. Emits save_pressed when clicked.
@export var save_button: Button
## Requests to leave the Settings panel. Emits exit_pressed when clicked.
@export var exit_button: Button

@export_group("Sound Tab Controls")
## Master volume slider, range 0.0–1.0.
@export var master_volume_slider: HSlider
## Music volume slider, range 0.0–1.0.
@export var music_volume_slider: HSlider
## Sound effects volume slider, range 0.0–1.0.
@export var sfx_volume_slider: HSlider

@export_group("Graphics Tab Controls")
## Graphics quality selector. Item indices match GraphicsQuality enum values.
@export var graphics_quality_option: OptionButton
## Toggles fullscreen display mode.
@export var fullscreen_checkbox: CheckBox
## Toggles vertical synchronization.
@export var vsync_checkbox: CheckBox

@export_group("Difficulty Tab Controls")
## Game difficulty selector. Item indices match Difficulty enum values.
@export var difficulty_option: OptionButton


func _ready() -> void:
	_populate_option_buttons()
	_configure_sliders()
	_connect_signals()


func validate_configuration() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if tab_container == null:
		errors.append("SettingsView: assign tab_container.")
	if save_button == null:
		errors.append("SettingsView: assign save_button.")
	if exit_button == null:
		errors.append("SettingsView: assign exit_button.")
	if master_volume_slider == null:
		errors.append("SettingsView: assign master_volume_slider.")
	if music_volume_slider == null:
		errors.append("SettingsView: assign music_volume_slider.")
	if sfx_volume_slider == null:
		errors.append("SettingsView: assign sfx_volume_slider.")
	if graphics_quality_option == null:
		errors.append("SettingsView: assign graphics_quality_option.")
	if fullscreen_checkbox == null:
		errors.append("SettingsView: assign fullscreen_checkbox.")
	if vsync_checkbox == null:
		errors.append("SettingsView: assign vsync_checkbox.")
	if difficulty_option == null:
		errors.append("SettingsView: assign difficulty_option.")
	return errors


## Synchronizes every control widget to the provided settings values without
## emitting setting_changed. Called by the presenter after
## SettingsController.load_settings() or revert() so the UI reflects persisted state.
func apply_settings(master_volume: float, music_volume: float, sfx_volume: float,
		graphics_quality: int, fullscreen: bool, vsync: bool,
		difficulty: int) -> void:
	if master_volume_slider != null:
		master_volume_slider.set_value_no_signal(master_volume)
	if music_volume_slider != null:
		music_volume_slider.set_value_no_signal(music_volume)
	if sfx_volume_slider != null:
		sfx_volume_slider.set_value_no_signal(sfx_volume)
	if graphics_quality_option != null:
		graphics_quality_option.select(graphics_quality)
	if fullscreen_checkbox != null:
		fullscreen_checkbox.set_pressed_no_signal(fullscreen)
	if vsync_checkbox != null:
		vsync_checkbox.set_pressed_no_signal(vsync)
	if difficulty_option != null:
		difficulty_option.select(difficulty)


## Returns the currently selected tab as a SettingsTab enum value.
func get_current_tab() -> NavigationEnums.SettingsTab:
	if tab_container == null:
		return NavigationEnums.SettingsTab.SOUND
	return tab_container.current_tab as NavigationEnums.SettingsTab


## Populates option buttons with labels matching the enum order so item indices
## align with enum numeric values. Selects sensible defaults.
func _populate_option_buttons() -> void:
	if graphics_quality_option != null:
		graphics_quality_option.clear()
		for label: String in GRAPHICS_QUALITY_LABELS:
			graphics_quality_option.add_item(label)
		graphics_quality_option.select(NavigationEnums.GraphicsQuality.MEDIUM)
	if difficulty_option != null:
		difficulty_option.clear()
		for label: String in DIFFICULTY_LABELS:
			difficulty_option.add_item(label)
		difficulty_option.select(NavigationEnums.Difficulty.NORMAL)


## Constrains volume sliders to the 0.0–1.0 range with 0.01 steps.
func _configure_sliders() -> void:
	for slider: HSlider in [master_volume_slider, music_volume_slider, sfx_volume_slider]:
		if slider != null:
			slider.min_value = 0.0
			slider.max_value = 1.0
			slider.step = 0.01


func _connect_signals() -> void:
	if tab_container != null and not tab_container.tab_changed.is_connected(_on_tab_changed):
		tab_container.tab_changed.connect(_on_tab_changed)
	if save_button != null and not save_button.pressed.is_connected(_on_save_pressed):
		save_button.pressed.connect(_on_save_pressed)
	if exit_button != null and not exit_button.pressed.is_connected(_on_exit_pressed):
		exit_button.pressed.connect(_on_exit_pressed)
	if master_volume_slider != null and not master_volume_slider.value_changed.is_connected(_on_master_volume_changed):
		master_volume_slider.value_changed.connect(_on_master_volume_changed)
	if music_volume_slider != null and not music_volume_slider.value_changed.is_connected(_on_music_volume_changed):
		music_volume_slider.value_changed.connect(_on_music_volume_changed)
	if sfx_volume_slider != null and not sfx_volume_slider.value_changed.is_connected(_on_sfx_volume_changed):
		sfx_volume_slider.value_changed.connect(_on_sfx_volume_changed)
	if graphics_quality_option != null and not graphics_quality_option.item_selected.is_connected(_on_graphics_quality_changed):
		graphics_quality_option.item_selected.connect(_on_graphics_quality_changed)
	if fullscreen_checkbox != null and not fullscreen_checkbox.toggled.is_connected(_on_fullscreen_toggled):
		fullscreen_checkbox.toggled.connect(_on_fullscreen_toggled)
	if vsync_checkbox != null and not vsync_checkbox.toggled.is_connected(_on_vsync_toggled):
		vsync_checkbox.toggled.connect(_on_vsync_toggled)
	if difficulty_option != null and not difficulty_option.item_selected.is_connected(_on_difficulty_changed):
		difficulty_option.item_selected.connect(_on_difficulty_changed)


func _on_tab_changed(tab: int) -> void:
	match tab:
		NavigationEnums.SettingsTab.SOUND:
			sound_tab_selected.emit()
		NavigationEnums.SettingsTab.GRAPHICS:
			graphics_tab_selected.emit()
		NavigationEnums.SettingsTab.DIFFICULTY:
			difficulty_tab_selected.emit()


func _on_save_pressed() -> void:
	save_pressed.emit()


func _on_exit_pressed() -> void:
	exit_pressed.emit()


func _on_master_volume_changed(value: float) -> void:
	setting_changed.emit(NavigationEnums.SettingsTab.SOUND, KEY_MASTER_VOLUME, value)


func _on_music_volume_changed(value: float) -> void:
	setting_changed.emit(NavigationEnums.SettingsTab.SOUND, KEY_MUSIC_VOLUME, value)


func _on_sfx_volume_changed(value: float) -> void:
	setting_changed.emit(NavigationEnums.SettingsTab.SOUND, KEY_SFX_VOLUME, value)


func _on_graphics_quality_changed(index: int) -> void:
	setting_changed.emit(NavigationEnums.SettingsTab.GRAPHICS, KEY_GRAPHICS_QUALITY, index)


func _on_fullscreen_toggled(pressed: bool) -> void:
	setting_changed.emit(NavigationEnums.SettingsTab.GRAPHICS, KEY_FULLSCREEN, pressed)


func _on_vsync_toggled(pressed: bool) -> void:
	setting_changed.emit(NavigationEnums.SettingsTab.GRAPHICS, KEY_VSYNC, pressed)


func _on_difficulty_changed(index: int) -> void:
	setting_changed.emit(NavigationEnums.SettingsTab.DIFFICULTY, KEY_DIFFICULTY, index)
