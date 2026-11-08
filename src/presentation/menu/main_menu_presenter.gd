class_name MainMenuPresenter
extends Node
## Composition root for the Main Menu scene. Wires UI views and dialogs to the
## logic controllers (NavigationController, SettingsController, SaveGameController),
## routes button presses to the appropriate controller, and updates panel
## visibility in response to screen_changed. Assign every reference below in
## the Inspector; no node paths are hardcoded. Follows the same ownership contract
## as FieldPrototypePresenter: logic owns state, presentation renders snapshots.

@export_group("Logic Controllers")
@export var navigation_controller: NavigationController
@export var settings_controller: SettingsController
@export var save_game_controller: SaveGameController

@export_group("Views")
@export var main_menu_view: MainMenuView
@export var settings_view: SettingsView
@export var about_us_view: AboutUsView
@export var play_menu_view: PlayMenuView

@export_group("Dialogs")
@export var discard_dialog: ConfirmationDialog
@export var exit_dialog: ConfirmationDialog

@export_group("Game")
## PackedScene loaded when the player starts or continues a game. When null the
## transition is aborted with a push_error and a status message so the player
## stays on the menu instead of silently failing.
@export var game_scene: PackedScene

@export_group("Status")
## Optional label for the save confirmation and error messages. Null-safe: the
## presenter works whether or not a label is assigned.
@export var status_label: Label

const SAVE_CONFIRMATION_TEXT := "Settings saved."


func _ready() -> void:
	var errors: PackedStringArray = _validate_references()
	if not errors.is_empty():
		_show_failure("\n".join(errors))
		return
	_connect_signals()
	# Load persisted settings before reflecting them in the SettingsView. A missing
	# file (first launch) loads defaults silently; a corrupt file emits load_failed
	# and falls back to defaults. All signals are connected before this call so the
	# load_failed handler can report the reason.
	settings_controller.load_settings()
	# Establish initial save-game existence so the Continue button starts correct.
	save_game_controller.refresh()
	play_menu_view.set_continue_enabled(save_game_controller.has_saved_game())
	# Enforce the entry-screen panel visibility regardless of scene defaults.
	_update_panel_visibility(navigation_controller.current_screen)


## Connects every view button, controller, and dialog signal exactly once.
func _connect_signals() -> void:
	# Main menu navigation buttons.
	_connect_once(main_menu_view.settings_pressed, _on_settings_pressed)
	_connect_once(main_menu_view.about_us_pressed, _on_about_us_pressed)
	_connect_once(main_menu_view.play_pressed, _on_play_pressed)
	_connect_once(main_menu_view.exit_pressed, _on_exit_pressed)
	# Settings panel buttons and controls. Tab selection is handled natively by
	# the TabContainer, so no tab_selected signals are routed through the presenter.
	_connect_once(settings_view.save_pressed, _on_save_pressed)
	_connect_once(settings_view.exit_pressed, _on_settings_exit_pressed)
	_connect_once(settings_view.setting_changed, _on_setting_changed)
	# About Us panel.
	_connect_once(about_us_view.back_pressed, _on_about_us_back_pressed)
	# Play menu buttons.
	_connect_once(play_menu_view.new_game_pressed, _on_new_game_pressed)
	_connect_once(play_menu_view.continue_pressed, _on_continue_pressed)
	# Controller state signals.
	_connect_once(navigation_controller.screen_changed, _on_screen_changed)
	_connect_once(navigation_controller.unsaved_exit_requested, _on_unsaved_exit_requested)
	_connect_once(settings_controller.dirty_changed, _on_dirty_changed)
	_connect_once(settings_controller.saved, _on_settings_saved)
	_connect_once(settings_controller.load_failed, _on_settings_load_failed)
	_connect_once(save_game_controller.save_state_changed, _on_save_state_changed)
	# Confirmation dialogs.
	_connect_once(discard_dialog.confirmed, _on_discard_confirmed)
	_connect_once(discard_dialog.canceled, _on_discard_canceled)
	_connect_once(exit_dialog.confirmed, _on_exit_confirmed)
	_connect_once(exit_dialog.canceled, _on_exit_canceled)


func _connect_once(source: Signal, callback: Callable) -> void:
	if not source.is_connected(callback):
		source.connect(callback)


func _validate_references() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if navigation_controller == null:
		errors.append("Presenter: assign navigation_controller.")
	if settings_controller == null:
		errors.append("Presenter: assign settings_controller.")
	if save_game_controller == null:
		errors.append("Presenter: assign save_game_controller.")
	if main_menu_view == null:
		errors.append("Presenter: assign main_menu_view.")
	else:
		errors.append_array(main_menu_view.validate_configuration())
	if settings_view == null:
		errors.append("Presenter: assign settings_view.")
	else:
		errors.append_array(settings_view.validate_configuration())
	if about_us_view == null:
		errors.append("Presenter: assign about_us_view.")
	else:
		errors.append_array(about_us_view.validate_configuration())
	if play_menu_view == null:
		errors.append("Presenter: assign play_menu_view.")
	else:
		errors.append_array(play_menu_view.validate_configuration())
	if discard_dialog == null:
		errors.append("Presenter: assign discard_dialog.")
	if exit_dialog == null:
		errors.append("Presenter: assign exit_dialog.")
	return errors


## Shows only the panel matching the current screen. The Main Menu stays visible
## behind the exit dialog; all menu panels hide once the game scene transition begins.
func _update_panel_visibility(screen: NavigationEnums.Screen) -> void:
	main_menu_view.visible = screen == NavigationEnums.Screen.MAIN_MENU \
			or screen == NavigationEnums.Screen.EXIT_DIALOG
	settings_view.visible = screen == NavigationEnums.Screen.SETTINGS
	about_us_view.visible = screen == NavigationEnums.Screen.ABOUT_US
	play_menu_view.visible = screen == NavigationEnums.Screen.PLAY_MENU


## Reflects the current working settings in the SettingsView controls without
## emitting setting_changed. Reads through the controller accessor to respect the
## ownership contract (presentation never touches SettingsState directly).
func _apply_settings_to_view() -> void:
	settings_view.apply_settings(
		float(settings_controller.get_value(NavigationEnums.SettingsTab.SOUND, SettingsView.KEY_MASTER_VOLUME)),
		float(settings_controller.get_value(NavigationEnums.SettingsTab.SOUND, SettingsView.KEY_MUSIC_VOLUME)),
		float(settings_controller.get_value(NavigationEnums.SettingsTab.SOUND, SettingsView.KEY_SFX_VOLUME)),
		int(settings_controller.get_value(NavigationEnums.SettingsTab.GRAPHICS, SettingsView.KEY_GRAPHICS_QUALITY)),
		bool(settings_controller.get_value(NavigationEnums.SettingsTab.GRAPHICS, SettingsView.KEY_FULLSCREEN)),
		bool(settings_controller.get_value(NavigationEnums.SettingsTab.GRAPHICS, SettingsView.KEY_VSYNC)),
		int(settings_controller.get_value(NavigationEnums.SettingsTab.DIFFICULTY, SettingsView.KEY_DIFFICULTY))
	)


# --- Main menu button handlers -----------------------------------------------

func _on_settings_pressed() -> void:
	navigation_controller.request_transition(NavigationEnums.Screen.SETTINGS)


func _on_about_us_pressed() -> void:
	navigation_controller.request_transition(NavigationEnums.Screen.ABOUT_US)


func _on_play_pressed() -> void:
	navigation_controller.request_transition(NavigationEnums.Screen.PLAY_MENU)


func _on_exit_pressed() -> void:
	navigation_controller.request_transition(NavigationEnums.Screen.EXIT_DIALOG)


# --- Settings panel handlers -------------------------------------------------

func _on_save_pressed() -> void:
	# save() emits saved() on success (which shows the confirmation) and preserves
	# dirty state on failure so the player can retry.
	if not settings_controller.save():
		_show_status("Could not save settings: %s" % settings_controller.last_error)


func _on_settings_exit_pressed() -> void:
	# NavigationController defers this to the discard dialog when unsaved changes exist.
	navigation_controller.request_transition(NavigationEnums.Screen.MAIN_MENU)


func _on_setting_changed(tab: NavigationEnums.SettingsTab, key: String, value: Variant) -> void:
	settings_controller.set_value(tab, key, value)


# --- About Us handler --------------------------------------------------------

func _on_about_us_back_pressed() -> void:
	navigation_controller.request_transition(NavigationEnums.Screen.MAIN_MENU)


# --- Play menu handlers ------------------------------------------------------

func _on_new_game_pressed() -> void:
	_start_game()


func _on_continue_pressed() -> void:
	_start_game()


## Transitions from the Play Menu into the game scene. Aborts with an error when
## game_scene is unassigned so the player remains on the menu. The state machine
## transition to GAME_SCENE is recorded before the scene swap.
func _start_game() -> void:
	if game_scene == null:
		push_error("MainMenuPresenter: game_scene is not assigned.")
		_show_status("Game scene not configured. Cannot start game.")
		return
	navigation_controller.request_transition(NavigationEnums.Screen.GAME_SCENE)
	# Returning to the Main Menu from the game is a future concern outside this
	# feature's scope; the current requirements only define forward navigation.
	get_tree().change_scene_to_file(game_scene.resource_path)


# --- Controller signal handlers ---------------------------------------------

func _on_screen_changed(screen: NavigationEnums.Screen) -> void:
	_update_panel_visibility(screen)
	match screen:
		NavigationEnums.Screen.SETTINGS:
			# Re-sync controls to the working state whenever Settings is (re)entered
			# so a reverted session shows the saved values rather than stale edits.
			_apply_settings_to_view()
		NavigationEnums.Screen.PLAY_MENU:
			# Re-check save existence each time the Play Menu opens and keep the
			# Continue option in sync.
			save_game_controller.refresh()
			play_menu_view.set_continue_enabled(save_game_controller.has_saved_game())
		NavigationEnums.Screen.EXIT_DIALOG:
			if exit_dialog != null:
				exit_dialog.popup_centered()


func _on_unsaved_exit_requested() -> void:
	# NavigationController stayed on SETTINGS; show the discard dialog over it.
	if discard_dialog != null:
		discard_dialog.popup_centered()


func _on_dirty_changed(is_dirty: bool) -> void:
	# Bridge settings dirty state to navigation so leaving Settings is deferred
	# while unsaved changes are pending a discard decision.
	navigation_controller.set_unsaved_settings(is_dirty)


func _on_settings_saved() -> void:
	# Save_Confirmation: a visual indicator that changes were persisted.
	_show_status(SAVE_CONFIRMATION_TEXT)


func _on_settings_load_failed(reason: String) -> void:
	_show_status(reason)


func _on_save_state_changed(has_save: bool) -> void:
	play_menu_view.set_continue_enabled(has_save)


# --- Dialog handlers ---------------------------------------------------------

func _on_discard_confirmed() -> void:
	# Discard: revert to the last saved state, then resolve the deferred exit.
	settings_controller.revert()
	navigation_controller.confirm_discard()


func _on_discard_canceled() -> void:
	# Keep the unsaved values and return to the Settings panel unchanged.
	navigation_controller.cancel_discard()


func _on_exit_confirmed() -> void:
	get_tree().quit()


func _on_exit_canceled() -> void:
	# Dismiss the dialog and return to the Main Menu.
	navigation_controller.request_transition(NavigationEnums.Screen.MAIN_MENU)


# --- Helpers -----------------------------------------------------------------

func _show_status(message: String) -> void:
	if status_label != null:
		status_label.text = message


func _show_failure(message: String) -> void:
	push_error(message)
	_show_status(message)
