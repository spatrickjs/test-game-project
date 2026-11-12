# Action Bar: Design

Layers: Logic owns state; Presentation observes. Data/Simulation untouched.

## Logic: `src/logic/farming/farming_controller.gd`

State
- `const DEFAULT_MAX_ACTIONS: int = 5`
- `_max_actions: int`, `_actions_remaining: int` (private; getters `get_max_actions()`, `get_actions_remaining()`).
- Initialized full on controller initialization / new game.

Signals
- `actions_remaining_changed(remaining: int, max: int)`
- `max_actions_changed(new_max: int)`
- Emit only after committed change, with local copies of values.

API
- `validate_max_actions(n: int) -> PackedStringArray` (empty = valid; n <= 0 invalid).
- `try_set_max_actions(n: int) -> bool`: validate; on failure set `last_error`, mutate nothing, no signals. On success set max, clamp remaining, emit `max_actions_changed` then one `actions_remaining_changed`.
- `adjust_actions_remaining(delta: int) -> void`: clamp to [0, max]; emit only if value changed. Also the test seam for setup.
- `reset_actions_remaining() -> void`: remaining = current max; emit once if changed.

Validation and consumption
- `action_error(action)`: append bar check (remaining <= 0 -> insufficient actions) after existing action validity so specific errors win. Shared by indicators, enqueue, arrival.
- `arrive_at_action`: bar check runs in the existing validate step on staged copy. On success, decrement as part of the commit, then emit once after commit. On failure nothing consumed; existing `action_finished(id, false, reason)` path.
- `enqueue_action`: rejects via `action_error`; does not reserve or consume.
- Movement path untouched.

## Logic: `src/logic/turns/turn_controller.gd`

- In `advance_turn()`, after successful commit, call `farming_controller.reset_actions_remaining()`, then existing `turn_completed` emission order preserved. Reuses the coordinator's existing reference; no new signal wiring.
- Early-return failure paths (uninitialized, pending actions, commit failure) do not touch the bar.
- Pending-actions block means bar reset never races queued commits.

## Presentation

- `src/presentation/world/field_prototype_presenter.gd`: `_connect_once` to `actions_remaining_changed`; forward to HUD view; show `last_error` on rejection via existing path; add reference validation.
- HUD view: new/extended view with exported Label reference, `validate_configuration()`, `set_counts(remaining, max)`. Scene node + Inspector wiring is a user-authored editor step; document, do not hand-edit.

## Tests

- `tests/logic/action_bar_test.gd` (SceneTree runtime): all feature scenarios; rejection without mutation snapshot compare (grid via `copy()`, RNG, counters, clock); signal counters for "notified once" and "after commit".
- Reuse `gameplay_test_fixture.gd` and `queued_action_test_driver.gd`.
- Invariant loop with seeded RNG over random max/adjust/consume sequences: 0 <= remaining <= max.
- Register in `tools/run_tests.py`.
- Interactive check: HUD display and turn-end reset on desktop/Android.

## Traceability

R1-R5,R8 -> T1,T2; R6,R7,R9,R10 -> T3; R11,R12 -> T4; R13 -> T5; all -> T6,T7.
