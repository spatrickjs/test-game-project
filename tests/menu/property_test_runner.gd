class_name PropertyTestRunner
extends RefCounted
## Reusable property-based test helper for the scene-management-and-navigation feature.
##
## Godot has no native property-based testing library, so this helper provides the
## randomized-input generation and iteration loop that property tests need. It follows
## the existing SceneTree-based test runner conventions (_check()-style assertions, PASS
## markers, and process exit codes) so the property test files in tests/menu/ can stay
## thin: each one extends SceneTree, builds a PropertyTestRunner, runs one or more
## properties, then calls quit(runner.finish("MENU_PROPERTY_PASS")).
##
## Usage in a property test file:
##     extends SceneTree
##     func _initialize() -> void:
##         var runner := PropertyTestRunner.new()
##         # Feature: scene-management-and-navigation, Property 1: Settings save clears dirty state
##         runner.run_property(1, "Settings save clears dirty state", func(r: PropertyTestRunner) -> bool:
##             r.describe_input("master_volume=%f" % r.volume())
##             # ... exercise the code under test ...
##             return not ctrl.is_dirty()
##         )
##         quit(runner.finish("MENU_PROPERTY_PASS"))
##
## Traceability tag (place as a comment above each run_property() call):
##     # Feature: scene-management-and-navigation, Property {number}: {property_text}
## Use PropertyTestRunner.property_tag() to produce the exact formatted string.

# Feature: scene-management-and-navigation

const FEATURE_NAME := "scene-management-and-navigation"
## Minimum number of randomized iterations every property must survive.
const MIN_ITERATIONS := 100

var _rng := RandomNumberGenerator.new()
var _failures: PackedStringArray = PackedStringArray()
var _property_id := 0
var _property_text := ""
var _iteration := 0
var _input_description := ""


func _init(seed: int = -1) -> void:
	# A nonnegative seed makes a run reproducible; the default randomizes for genuine PBT.
	if seed >= 0:
		_rng.seed = seed
	else:
		_rng.randomize()


# ---------------------------------------------------------------------------
# Random input generators
# ---------------------------------------------------------------------------

## A random float within [min_value, max_value] (inclusive). Use for volumes and any
## scalar that may fall outside a valid range during validation edge-case tests.
func float_range(min_value: float, max_value: float) -> float:
	return _rng.randf_range(min_value, max_value)

## A random int within [min_value, max_value] (inclusive).
func int_range(min_value: int, max_value: int) -> int:
	return _rng.randi_range(min_value, max_value)

## A random boolean. Use for SaveGameController existence and SettingsState toggles.
func boolean() -> bool:
	return _rng.randf() < 0.5

## A random element from a non-empty array. Use to pick setting keys or other enums.
func element(options: Array) -> Variant:
	assert(options.size() > 0, "element() requires a non-empty array")
	if options.is_empty():
		return null
	return options[_rng.randi_range(0, options.size() - 1)]

## A random valid volume in [0.0, 1.0] (for SettingsState volume fields).
func volume() -> float:
	return float_range(0.0, 1.0)

## A random Screen value (for NavigationController transitions).
func screen() -> NavigationEnums.Screen:
	match _rng.randi_range(0, 6):
		0: return NavigationEnums.Screen.MAIN_MENU
		1: return NavigationEnums.Screen.SETTINGS
		2: return NavigationEnums.Screen.ABOUT_US
		3: return NavigationEnums.Screen.PLAY_MENU
		4: return NavigationEnums.Screen.DISCARD_DIALOG
		5: return NavigationEnums.Screen.EXIT_DIALOG
		_: return NavigationEnums.Screen.GAME_SCENE

## A random SettingsTab value (for SettingsController categories).
func settings_tab() -> NavigationEnums.SettingsTab:
	match _rng.randi_range(0, 2):
		0: return NavigationEnums.SettingsTab.SOUND
		1: return NavigationEnums.SettingsTab.GRAPHICS
		_: return NavigationEnums.SettingsTab.DIFFICULTY

## A random GraphicsQuality value (for SettingsState.graphics_quality).
func graphics_quality() -> NavigationEnums.GraphicsQuality:
	match _rng.randi_range(0, 2):
		0: return NavigationEnums.GraphicsQuality.LOW
		1: return NavigationEnums.GraphicsQuality.MEDIUM
		_: return NavigationEnums.GraphicsQuality.HIGH

## A random Difficulty value (for SettingsState.difficulty).
func difficulty() -> NavigationEnums.Difficulty:
	match _rng.randi_range(0, 2):
		0: return NavigationEnums.Difficulty.EASY
		1: return NavigationEnums.Difficulty.NORMAL
		_: return NavigationEnums.Difficulty.HARD


# ---------------------------------------------------------------------------
# Counterexample reporting
# ---------------------------------------------------------------------------

## Records a human-readable description of the current randomized input so a failing
## iteration's counterexample can be understood. Call this inside the check callable
## after generating inputs, before asserting.
func describe_input(description: String) -> void:
	_input_description = description

## _check()-style assertion helper. Records a failure (tagged with the current property
## and iteration) when condition is false.
func check(condition: bool, label: String) -> void:
	if not condition:
		_record(label)


func _record(label: String) -> void:
	var header: String = "FAIL: Property %d: %s | iteration %d" % [_property_id, _property_text, _iteration]
	if not _input_description.is_empty():
		header += " | input: %s" % _input_description
	_failures.append("%s | %s" % [header, label])


# ---------------------------------------------------------------------------
# Property runner
# ---------------------------------------------------------------------------

## Runs a property check for at least MIN_ITERATIONS iterations. The check callable
## receives this runner, generates randomized inputs via its generators, describes the
## input for reporting (describe_input), and returns true when the property holds for
## that iteration (or uses runner.check() for finer-grained assertions). The first
## failing iteration is recorded as a counterexample and iteration stops for that
## property (standard property-based testing behavior).
func run_property(property_id: int, property_text: String, property_check: Callable, iterations: int = MIN_ITERATIONS) -> void:
	_property_id = property_id
	_property_text = property_text
	var count: int = maxi(iterations, MIN_ITERATIONS)
	var failures_before: int = _failures.size()
	for i in count:
		_iteration = i
		_input_description = ""
		var result: Variant = property_check.call(self)
		if result is bool and not bool(result):
			_record("property check returned false")
		if _failures.size() > failures_before:
			break


## True when every run property has held across all of its iterations.
func passed() -> bool:
	return _failures.is_empty()


## Prints the pass marker when all properties passed, or reports every recorded
## counterexample via printerr (matching the existing FAIL: convention). Returns the
## exit code the SceneTree test script should pass to quit().
func finish(pass_marker: String) -> int:
	if _failures.is_empty():
		print(pass_marker)
		return 0
	for failure: String in _failures:
		printerr(failure)
	return 1


## Returns the traceability tag for a design-document property. Property test files
## should place this exact string as a comment above each run_property() call.
static func property_tag(property_id: int, property_text: String) -> String:
	return "# Feature: %s, Property %d: %s" % [FEATURE_NAME, property_id, property_text]
