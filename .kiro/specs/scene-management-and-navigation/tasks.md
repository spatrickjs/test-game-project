# Implementation Plan: Scene Management and Navigation

## Overview

The implementation adds a Main Menu scene and navigation system to the Godot 4.7.2 game, following the project's four-layer architecture (Data, Simulation, Logic, Presentation). The work proceeds bottom-up: data models and enums first, then logic controllers (navigation state machine, settings persistence, save-game existence), then presentation views, then the composition root that wires everything together into a `MainMenuScene`, and finally integration tests. All code uses typed GDScript, `@export` composition-root wiring, and signal-based communication matching the existing `FieldPrototypePresenter` / `FarmingController` pattern. Property-based tests cover the nine correctness properties from the design; integration tests cover the Gherkin acceptance scenarios in `features/main_menu.feature`.

## Tasks

- [x] 1. Data layer — enums, state models, and property test infrastructure
  - Create directory structure: `src/logic/menu/`, `src/presentation/menu/`, `tests/menu/`
  - [x] 1.1 Create NavigationEnums with Screen, SettingsTab, GraphicsQuality, and Difficulty enums
    - Create `src/data/enums/navigation_enums.gd` as a `RefCounted` class following `simulation_enums.gd` conventions (explicit numeric values for forward-compatibility)
    - Define `Screen` (MAIN_MENU, SETTINGS, ABOUT_US, PLAY_MENU, DISCARD_DIALOG, EXIT_DIALOG, GAME_SCENE), `SettingsTab` (SOUND, GRAPHICS, DIFFICULTY), `GraphicsQuality` (LOW, MEDIUM, HIGH), `Difficulty` (EASY, NORMAL, HARD)
    - _Requirements: 1.1, 2.2, 2.3, 2.4, 6.4_

  - [x] 1.2 Create SettingsState model with sound, graphics, and difficulty fields
    - Create `src/data/state/settings_state.gd` as a `RefCounted` class following `field_grid_state.gd` conventions
    - Fields with defaults: master_volume (1.0, range 0.0–1.0), music_volume (0.8), sfx_volume (0.8), graphics_quality (MEDIUM), fullscreen (false), vsync (true), difficulty (NORMAL)
    - Implement `copy() -> SettingsState` (deep copy), `equals(other: SettingsState) -> bool` (compare all fields), `validate() -> PackedStringArray` (report out-of-range volumes and invalid enum values without mutating)
    - _Requirements: 2.2, 2.3, 2.4, 3.1_

  - [x] 1.3 Create SavedGameMetadata model
    - Create `src/data/state/saved_game_metadata.gd` as a `RefCounted` class
    - Fields: exists (bool, default false), timestamp (int, Unix epoch seconds), turn_index (int), display_name (String)
    - _Requirements: 6.3, 6.4_

  - [x] 1.4 Create property test runner helper
    - Create `tests/menu/property_test_runner.gd` following the existing SceneTree-based test runner pattern (headless, `_check()` assertions, PASS markers, exit codes)
    - Provide a randomized-input generator API that runs each property for a minimum of 100 iterations
    - Tag each property with a comment: `# Feature: scene-management-and-navigation, Property {number}: {property_text}`
    - _Requirements: 3.1, 3.4, 4.1, 6.4_

  - [x]* 1.5 Write unit tests for SettingsState validation and copy/equals
    - Create `tests/menu/settings_state_unit_test.gd` extending `SceneTree`; print `MENU_SETTINGS_STATE_UNIT_PASS`
    - Test `validate()` edge cases (volumes out of [0.0, 1.0], invalid enum values), `copy()` independence (mutating a copy does not affect the original), `equals()` true and false cases
    - _Requirements: 2.2, 2.3, 2.4_

- [x] 2. SettingsController — dirty tracking and persistence
  - [x] 2.1 Implement SettingsController with load, set_value, save, revert, and dirty tracking
    - Create `src/logic/menu/settings_controller.gd` as a `Node` following `turn_controller.gd` conventions (`last_error: String`, signals)
    - Own a working `SettingsState` (`state`) and a last-persisted copy (`_saved_state`); config path `user://settings.cfg`
    - Signals: `dirty_changed(is_dirty: bool)`, `saved()`, `load_failed(reason: String)`
    - `load_settings() -> bool` reads `ConfigFile` (defaults if file missing; emits `load_failed` + falls back to defaults if corrupt)
    - `set_value(category: SettingsTab, key: String, value: Variant) -> void` updates working state, validates via `SettingsState.validate()` (rejects invalid values), emits `dirty_changed` based on comparison with saved state
    - `save() -> bool` serializes to `ConfigFile`, copies `state` into `_saved_state`, emits `saved` then `dirty_changed(false)`; returns `false` and sets `last_error` on write failure (dirty state preserved for retry)
    - `revert() -> void` copies `_saved_state` back into `state`, emits `dirty_changed(false)`
    - `is_dirty() -> bool` and `get_value(category, key) -> Variant` accessors
    - _Requirements: 2.2, 2.3, 2.4, 3.1, 3.2, 3.3, 3.4, 4.1_

  - [x]* 2.2 Write property test: save clears dirty state
    - Add to `tests/menu/settings_state_property_test.gd` using the property test runner (100+ iterations)
    - **Property 1: Settings save clears dirty state**
    - For any `SettingsState` with one or more field values differing from the saved state, after `save()` succeeds, `is_dirty()` SHALL return `false` and the working state SHALL equal the saved state
    - **Validates: Requirements 3.1, 3.4**

  - [ ]* 2.3 Write property test: revert restores saved state
    - Add to `tests/menu/settings_state_property_test.gd`
    - **Property 2: Settings revert restores saved state**
    - For any `SettingsState` with unsaved modifications, after `revert()` is called, the working state SHALL equal the last saved state and `is_dirty()` SHALL return `false`
    - **Validates: Requirements 4.1**

  - [ ]* 2.4 Write property test: dirty tracking reflects value differences
    - Add to `tests/menu/settings_state_property_test.gd`
    - **Property 3: Settings dirty tracking reflects value differences**
    - For any sequence of `set_value` calls, `is_dirty()` SHALL return `true` if and only if the working state differs from the saved state in at least one field
    - **Validates: Requirements 3.1, 3.2, 3.3**

  - [ ]* 2.5 Write property test: serialization round trip
    - Add to `tests/menu/settings_state_property_test.gd`; print `MENU_PROPERTY_PASS`
    - **Property 4: Settings serialization round trip**
    - For any valid `SettingsState`, serializing to `ConfigFile` and deserializing back SHALL produce a `SettingsState` that equals the original
    - **Validates: Requirements 3.1**

  - [ ]* 2.6 Write unit tests for SettingsController edge cases
    - Create `tests/menu/settings_controller_unit_test.gd` extending `SceneTree`; print `MENU_SETTINGS_CONTROLLER_UNIT_PASS`
    - First-launch with no settings file (defaults load correctly), missing config sections (per-section defaults applied), corrupt file (`load_failed` emitted + defaults fallback)
    - _Requirements: 3.1_

- [x] 3. NavigationController — navigation state machine
  - [x] 3.1 Implement NavigationController with state machine transitions
    - Create `src/logic/menu/navigation_controller.gd` as a `Node` following `turn_controller.gd` conventions
    - Own `current_screen: NavigationEnums.Screen` (default MAIN_MENU) and `_has_unsaved_settings: bool`
    - Signals: `screen_changed(screen: Screen)`, `unsaved_exit_requested()`
    - `request_transition(target: Screen) -> bool` validates against the state machine; if SETTINGS→MAIN_MENU with unsaved changes, emits `unsaved_exit_requested` and returns `false` (transition deferred until dialog resolves); applies transition and emits `screen_changed` on success
    - `set_unsaved_settings(has_unsaved: bool) -> void` called by SettingsController to inform navigation of dirty state
    - `confirm_discard() -> void` transitions to MAIN_MENU and clears the unsaved flag
    - `cancel_discard() -> void` returns to SETTINGS, preserving unsaved values
    - _Requirements: 1.1, 2.1, 3.2, 3.3, 4.1, 4.2, 5.1, 5.2, 6.1, 7.1, 7.3_

  - [x]* 3.2 Write property test: navigation transitions are valid
    - Add to `tests/menu/navigation_controller_property_test.gd` using the property test runner (100+ iterations)
    - **Property 5: Navigation transitions are valid**
    - For any current screen and requested target, `request_transition` SHALL apply the transition if and only if it is valid in the state machine, and `current_screen` SHALL always be a valid `Screen` enum value after the call
    - **Validates: Requirements 1.1, 2.1, 3.2, 3.3, 4.1, 4.2, 5.1, 5.2, 6.1, 7.1, 7.3**

  - [ ]* 3.3 Write property test: unsaved settings exit triggers discard dialog
    - Add to `tests/menu/navigation_controller_property_test.gd`
    - **Property 6: Unsaved settings exit triggers discard dialog**
    - For any state where Settings has unsaved changes, requesting SETTINGS→MAIN_MENU SHALL emit `unsaved_exit_requested` and SHALL NOT change `current_screen` until the discard dialog resolves
    - **Validates: Requirements 3.3**

  - [ ]* 3.4 Write property test: discard confirm returns to main menu
    - Add to `tests/menu/navigation_controller_property_test.gd`
    - **Property 7: Discard confirm returns to main menu**
    - For any state where the discard dialog is active, confirming the discard SHALL set `current_screen` to MAIN_MENU and clear the unsaved settings flag
    - **Validates: Requirements 4.1**

  - [ ]* 3.5 Write property test: discard cancel returns to settings
    - Add to `tests/menu/navigation_controller_property_test.gd`; print `MENU_PROPERTY_PASS`
    - **Property 8: Discard cancel returns to settings**
    - For any state where the discard dialog is active, canceling the discard SHALL set `current_screen` back to SETTINGS and preserve the unsaved settings values unchanged
    - **Validates: Requirements 4.2**

- [x] 4. SaveGameController — save existence management
  - [x] 4.1 Implement SaveGameController with save existence check and metadata
    - Create `src/logic/menu/save_game_controller.gd` as a `Node` following existing controller conventions
    - Save path `user://savegame.dat`; signal `save_state_changed(has_save: bool)`
    - `has_saved_game() -> bool` via `FileAccess.file_exists`; `refresh() -> void` re-checks existence and emits `save_state_changed` if the result changed since the last check (called when Play Menu opens and after a new game starts); `get_metadata() -> SavedGameMetadata` reads and parses the save header (returns `null` if no save exists or parsing fails)
    - _Requirements: 6.3, 6.4_

  - [x]* 4.2 Write property test: continue option disabled without save
    - Create `tests/menu/save_game_controller_property_test.gd` using the property test runner (100+ iterations); print `MENU_PROPERTY_PASS`
    - **Property 9: Continue option disabled without save**
    - `has_saved_game()` SHALL return `true` if and only if the save file exists at the configured path, and the Continue button SHALL be disabled when `has_saved_game()` returns `false`
    - **Validates: Requirements 6.4**

- [x] 5. Checkpoint — logic and data layer
  - Ensure all logic and data layer tests pass, ask the user if questions arise.

- [x] 6. Presentation views — menu UI components
  - [x] 6.1 Implement MainMenuView with four navigation buttons and signals
    - Create `src/presentation/menu/main_menu_view.gd` as a `Control` script; own Settings, About Us, Play, and Exit Game button nodes visible after the Game loads
    - Signals: `settings_pressed`, `about_us_pressed`, `play_pressed`, `exit_pressed` connected to the respective button `pressed` signals
    - _Requirements: 1.2_

  - [x] 6.2 Implement SettingsView with TabContainer and setting controls
    - Create `src/presentation/menu/settings_view.gd` as a `Control` script wrapping a `TabContainer` with three tabs (Sound, Graphics, Difficulty)
    - Signals: `sound_tab_selected`, `graphics_tab_selected`, `difficulty_tab_selected`, `save_pressed`, `exit_pressed`, `setting_changed(tab: SettingsTab, key: String, value: Variant)`
    - Host control widgets: volume sliders for the Sound tab, option buttons for graphics quality and difficulty, checkboxes for fullscreen and vsync
    - _Requirements: 2.1, 2.2, 2.3, 2.4_

  - [x] 6.3 Implement AboutUsView with info display and back signal
    - Create `src/presentation/menu/about_us_view.gd` as a `Control` script displaying static text about the Game and its developers
    - Signal: `back_pressed`
    - _Requirements: 5.2, 5.3_

  - [x] 6.4 Implement PlayMenuView with New Game and Continue buttons
    - Create `src/presentation/menu/play_menu_view.gd` as a `Control` script holding New Game and Continue button references
    - Signals: `new_game_pressed`, `continue_pressed`; the Continue button `disabled` property is set externally by the presenter based on `SaveGameController`
    - _Requirements: 6.1, 6.4_

- [x] 7. Composition root — MainMenuPresenter and scene
  - [x] 7.1 Implement MainMenuPresenter wiring controllers to views and dialogs
    - Create `src/presentation/menu/main_menu_presenter.gd` as a `Node` following `field_prototype_presenter.gd` conventions (`@export_group`, `_validate_references`, `_connect_signals`, `_connect_once`)
    - `@export` references to NavigationController, SettingsController, SaveGameController, all four views, discard and exit `ConfirmationDialog`s, and the game `PackedScene`
    - In `_ready()`: validate references, connect all button signals and controller signals, call `settings_controller.load_settings()` and `save_game_controller.refresh()`
    - Route button presses to the appropriate controller; update panel visibility in response to `screen_changed`; enable/disable the Continue button based on `save_state_changed`
    - Discard dialog `confirmed` → `settings_controller.revert()` + `navigation_controller.confirm_discard()`; `canceled` → `navigation_controller.cancel_discard()`
    - Exit dialog `confirmed` → `get_tree().quit()`; `canceled` → dismiss dialog (stay on Main Menu)
    - New Game / Continue → `get_tree().change_scene_to_file()` to the game scene; log `push_error` and show status if `game_scene` is unassigned
    - _Requirements: 1.1, 1.2, 2.1, 3.1, 3.2, 3.3, 4.1, 4.2, 5.1, 5.2, 6.1, 6.2, 6.3, 6.4, 7.1, 7.2, 7.3_

  - [x] 7.2 Build MainMenuScene.tscn composing all views, controllers, and dialogs
    - Create `src/presentation/menu/main_menu.tscn` with MainMenuPresenter as the root `Node`
    - Add child controller nodes (NavigationController, SettingsController, SaveGameController) and view `Control` nodes (MainMenuView, SettingsView, AboutUsView, PlayMenuView) stacked with visibility toggled by the presenter
    - Add two `ConfirmationDialog` nodes for the discard and exit dialogs
    - Wire all `@export` references in the Inspector
    - _Requirements: 1.1, 1.2, 2.1, 5.1, 6.1, 7.1_

  - [x] 7.3 Set MainMenuScene as the project main scene in project.godot
    - Update `run/main_scene` in `project.godot` to reference the MainMenuScene (via UID or `res://` path), replacing the field prototype scene as the entry point
    - _Requirements: 1.1_

- [x] 8. Integration and end-to-end tests
  - [x] 8.1 Register menu test files in the test runner
    - Add all created `tests/menu/*.gd` test file paths to the `tests` list in `tools/run_tests.py` following the existing pattern
    - Ensure property tests print `MENU_PROPERTY_PASS` and integration tests print `MENU_<area>_PASS`; reject engine errors and warnings
    - _Requirements: 1.1, 2.1, 3.1, 6.1, 7.1_

  - [ ]* 8.2 Write integration test: main menu navigation
    - Create `tests/menu/main_menu_navigation_test.gd` extending `SceneTree`; print `MENU_NAVIGATION_PASS`
    - Instantiate `MainMenuScene`, simulate button clicks via `push_input`, verify panel visibility and screen transitions (Settings open, tab switching, About Us open and back, Play menu open)
    - _Requirements: 1.1, 1.2, 2.1, 2.2, 2.3, 2.4, 5.1, 5.2, 5.3_

  - [ ]* 8.3 Write integration test: settings panel save/revert and discard dialog
    - Create `tests/menu/settings_panel_test.gd` extending `SceneTree`; print `MENU_SETTINGS_PASS`
    - Tab switching order (Sound → Graphics → Difficulty), setting changes, save confirmation, exit-with-unsaved discard dialog, discard confirm (revert + return to main menu), discard cancel (return to settings with values retained)
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 4.1, 4.2_

  - [ ]* 8.4 Write integration test: play menu New Game and Continue states
    - Create `tests/menu/play_menu_test.gd` extending `SceneTree`; print `MENU_PLAY_PASS`
    - Continue disabled when no save exists, enabled when a save file is present, scene transition triggered on New Game and on Continue
    - _Requirements: 6.1, 6.2, 6.3, 6.4_

  - [ ]* 8.5 Write integration test: exit confirmation dialog
    - Create `tests/menu/exit_confirmation_test.gd` extending `SceneTree`; print `MENU_EXIT_PASS`
    - Exit dialog displayed on Exit Game, confirm triggers quit (verify quit requested), cancel dismisses dialog and returns to main menu
    - _Requirements: 7.1, 7.2, 7.3_

- [x] 9. Final checkpoint — ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability to `requirements.md` and the Gherkin scenarios in `features/main_menu.feature`
- Checkpoints ensure incremental validation; the logic/data checkpoint (Task 5) validates pure components before UI integration
- Property tests validate the nine universal correctness properties from the design document
- Unit tests validate specific examples and edge cases (first-launch, missing or corrupt files, tab order)
- Integration tests exercise the Gherkin acceptance scenarios end-to-end via simulated input
- All code follows typed GDScript and the existing composition-root / signal-based communication pattern

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "1.3", "1.4", "6.1", "6.3", "6.4"] },
    { "id": 1, "tasks": ["1.2", "3.1", "6.2"] },
    { "id": 2, "tasks": ["2.1", "4.1", "1.5"] },
    { "id": 3, "tasks": ["3.2", "2.2", "4.2", "2.6", "7.1"] },
    { "id": 4, "tasks": ["2.3", "3.3", "7.2"] },
    { "id": 5, "tasks": ["2.4", "3.4", "7.3", "8.2", "8.3", "8.4", "8.5"] },
    { "id": 6, "tasks": ["2.5", "3.5"] },
    { "id": 7, "tasks": ["8.1"] }
  ]
}
```
