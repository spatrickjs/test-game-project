class_name NavigationController
extends Node
## Pure-logic navigation state machine. Validates screen transitions and defers
## the Settings exit while unsaved changes are pending a discard decision.
## Presentation listens to the signals and updates panel visibility; it never
## mutates current_screen directly. Tab switches and save actions stay on Settings.

signal screen_changed(screen: NavigationEnums.Screen)
signal unsaved_exit_requested()

var current_screen: NavigationEnums.Screen = NavigationEnums.Screen.MAIN_MENU
var _has_unsaved_settings: bool = false
var last_error: String = ""


## Requests a transition to the target screen. Returns true when the transition
## was applied and screen_changed was emitted. When the player attempts to leave
## Settings with unsaved changes, the transition is deferred: the controller emits
## unsaved_exit_requested and returns false so the presenter can show the discard
## dialog. The actual transition happens once confirm_discard() resolves it.
func request_transition(target: NavigationEnums.Screen) -> bool:
	if not _is_valid_transition(current_screen, target):
		last_error = "Transition from %s to %s is not allowed." % [
			NavigationEnums.Screen.find_key(current_screen),
			NavigationEnums.Screen.find_key(target),
		]
		return false
	# Defer leaving Settings until the player decides whether to discard unsaved work.
	if current_screen == NavigationEnums.Screen.SETTINGS \
			and target == NavigationEnums.Screen.MAIN_MENU \
			and _has_unsaved_settings:
		unsaved_exit_requested.emit()
		last_error = ""
		return false
	current_screen = target
	last_error = ""
	screen_changed.emit(current_screen)
	return true


## Called by SettingsController to keep navigation informed of dirty state so the
## Settings exit can be deferred while unsaved changes exist.
func set_unsaved_settings(has_unsaved: bool) -> void:
	_has_unsaved_settings = has_unsaved


## Resolves a deferred Settings exit in favour of discarding: moves ownership to
## the Main Menu and clears the unsaved flag so future exits are immediate.
func confirm_discard() -> void:
	_has_unsaved_settings = false
	current_screen = NavigationEnums.Screen.MAIN_MENU
	last_error = ""
	screen_changed.emit(current_screen)


## Resolves a deferred Settings exit in favour of keeping the changes: returns to
## the Settings screen with the unsaved flag preserved so the values remain editable.
func cancel_discard() -> void:
	current_screen = NavigationEnums.Screen.SETTINGS
	last_error = ""
	screen_changed.emit(current_screen)


## Transition table derived from the design's navigation state diagram. The discard
## dialog is resolved via confirm_discard/cancel_discard rather than request_transition,
## so no transitions originate from DISCARD_DIALOG here. GAME_SCENE is terminal.
func _is_valid_transition(from: NavigationEnums.Screen, to: NavigationEnums.Screen) -> bool:
	match from:
		NavigationEnums.Screen.MAIN_MENU:
			return to == NavigationEnums.Screen.SETTINGS \
				or to == NavigationEnums.Screen.ABOUT_US \
				or to == NavigationEnums.Screen.PLAY_MENU \
				or to == NavigationEnums.Screen.EXIT_DIALOG
		NavigationEnums.Screen.SETTINGS:
			# Self-transition covers tab switches and save actions that stay on Settings.
			return to == NavigationEnums.Screen.MAIN_MENU \
				or to == NavigationEnums.Screen.SETTINGS
		NavigationEnums.Screen.ABOUT_US:
			return to == NavigationEnums.Screen.MAIN_MENU
		NavigationEnums.Screen.PLAY_MENU:
			return to == NavigationEnums.Screen.MAIN_MENU \
				or to == NavigationEnums.Screen.GAME_SCENE
		NavigationEnums.Screen.EXIT_DIALOG:
			return to == NavigationEnums.Screen.MAIN_MENU
		_:
			# DISCARD_DIALOG and GAME_SCENE are terminal/implicit within the menu system.
			return false
