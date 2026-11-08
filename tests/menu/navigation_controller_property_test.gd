extends SceneTree
## Property-based tests for NavigationController navigation state-machine behavior.
## Uses tests/menu/property_test_runner.gd for randomized input generation.
## Validates: Requirements 1.1, 2.1, 3.2, 3.3, 4.1, 4.2, 5.1, 5.2, 6.1, 7.1, 7.3

func _initialize() -> void:
	var runner := PropertyTestRunner.new()
	var controller := NavigationController.new()

	# Feature: scene-management-and-navigation, Property 5: Navigation transitions are valid
	runner.run_property(5, "Navigation transitions are valid", func(r: PropertyTestRunner) -> bool:
		# Pick any current screen and any requested target.
		var from_screen: NavigationEnums.Screen = r.screen()
		var target: NavigationEnums.Screen = r.screen()
		# Set the current screen directly and clear unsaved settings so the base
		# transition table is exercised cleanly. The SETTINGS->MAIN_MENU exit with
		# unsaved changes defers the transition to the discard dialog and returns
		# false despite being a valid table entry; Properties 6-8 cover that path.
		controller.current_screen = from_screen
		controller.set_unsaved_settings(false)
		r.describe_input("from=%s target=%s" % [
			NavigationEnums.Screen.find_key(from_screen),
			NavigationEnums.Screen.find_key(target),
		])

		var expected_valid: bool = _is_valid_transition(from_screen, target)
		var result: bool = controller.request_transition(target)

		# request_transition SHALL apply the transition if and only if it is a valid
		# transition in the state machine.
		r.check(result == expected_valid, "return value: expected=%s got=%s" % [expected_valid, result])
		if expected_valid:
			r.check(controller.current_screen == target, "valid transition: current_screen expected=%s got=%s" % [
				NavigationEnums.Screen.find_key(target),
				NavigationEnums.Screen.find_key(controller.current_screen),
			])
		else:
			r.check(controller.current_screen == from_screen, "invalid transition: current_screen expected=%s got=%s" % [
				NavigationEnums.Screen.find_key(from_screen),
				NavigationEnums.Screen.find_key(controller.current_screen),
			])
		# current_screen SHALL always be a valid Screen enum value after the call.
		r.check(_is_valid_screen(controller.current_screen), "current_screen is a valid Screen enum value: %d" % controller.current_screen)

		return true
	)

	controller.free()
	quit(runner.finish("MENU_PROPERTY_PASS"))


## Independent encoding of the design's navigation state-machine transition table,
## derived from the state diagram in design.md. Used as the oracle the controller
## is checked against; it deliberately does not call the controller's own
## _is_valid_transition() to avoid a circular test.
func _is_valid_transition(from: NavigationEnums.Screen, to: NavigationEnums.Screen) -> bool:
	match from:
		NavigationEnums.Screen.MAIN_MENU:
			return to == NavigationEnums.Screen.SETTINGS \
				or to == NavigationEnums.Screen.ABOUT_US \
				or to == NavigationEnums.Screen.PLAY_MENU \
				or to == NavigationEnums.Screen.EXIT_DIALOG
		NavigationEnums.Screen.SETTINGS:
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
			# DISCARD_DIALOG and GAME_SCENE are terminal/implicit within the menu
			# system; no request_transition originates from them (discard resolves
			# via confirm_discard()/cancel_discard(), GAME_SCENE is terminal).
			return false


## A valid Screen enum value is one of the defined Screen constants (MAIN_MENU..GAME_SCENE).
func _is_valid_screen(screen: NavigationEnums.Screen) -> bool:
	return screen >= NavigationEnums.Screen.MAIN_MENU and screen <= NavigationEnums.Screen.GAME_SCENE
