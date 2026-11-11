# Day & Night Cycle — repo findings

Feature-scoped context for implementing `day_night_cycle.feature`. Verified against the
codebase at the time of writing. Read only the section you need; do not load whole files.

## Entry points and key code

| File | Symbol | Role for this feature |
|---|---|---|
| `src/logic/turns/turn_controller.gd` | `TurnController` | Owns the discrete clock. `advance_turn() -> bool`, `signal turn_completed(turn_index)`, `turn_index`, `last_error`, `reset_clock()`. Header comment: "Manual discrete clock. No frame callback or timer drives simulation." |
| `src/logic/farming/farming_controller.gd` | `FarmingController` | Owns the live grid. `advance_simulated_turn()` is the turn transaction; refuses if `has_pending_actions()`. Emits `action_queue_changed`, `action_finished`, `queued_harvest_completed`. Comment: "Transaction boundary: no growth or epidemic state survives a failed turn." |
| `src/logic/turns/game_state_manager.gd` | `GameStateManager` | `turn_limit` (default 24), `score_goal`, `is_playing()`, `check_turn_limit()`, `signal game_ended(won: bool)`. Drives win/lose. |
| `src/presentation/world/field_prototype_presenter.gd` | `FieldPrototypePresenter` | Composition root. `_on_next_turn_pressed()` calls `turn_controller.advance_turn()`; `_on_action_queue_changed()` gates the End Turn button. Owns `_start_overlay` / `_end_overlay` (game over). |
| `src/presentation/world/field_world_view.gd` | `FieldWorldView` | World rendering, camera, overlays (crop, selection, grass, fence). No day/night visual exists here yet. |
| `src/logic/menu/save_game_controller.gd` | `SaveGameController` | Persists `metadata.turn_index` (default 0 on older saves). Day/night derives from turn_index, so it restores for free — unless night is a transient interstitial phase (then its restore value must be defined). |

## Turn flow as implemented (synchronous)

`advance_turn()` is one synchronous call; there is no async "night" phase in Logic:

1. Validate: `game_state_manager.is_playing()`, not `_advancing`, farming/sim/catalog present, `disease_database.validate()`. Any failure → `last_error` set, return false, `turn_index` unchanged.
2. `_advancing = true`; `farming_controller.advance_simulated_turn(...)`. On failure → `last_error = farming_controller.last_error`, `_advancing = false`, return false (copy-on-stage: no partial grid/RNG state).
3. `turn_index += 1`; `game_state_manager.check_turn_limit(turn_index)`; `disease_activation_controller.report_committed(...)`; `turn_completed.emit(turn_index)`; `_advancing = false`.

So the feature's split ("Ending the turn shows night / sim advances" then "Night resolves the turn / committed / observers notified") maps to **one** `advance_turn()` call. "Observers notified after the commit" is accurate: `turn_completed`, `introduction_committed`, and `queued_harvest_completed` all emit after the grid is committed (see `farming_controller.gd` comments: "Both cells are already committed before any observer receives a signal").

**Gap to resolve:** the feature implies night is a *viewable* interstitial between turns, but the code emits a single `turn_completed` and the player can act again immediately (buttons re-enable when queue is empty and `is_playing()`). There is **no "next turn begins" signal**. Decide one of:
- Night is a one-frame resolution flash driven by `turn_completed` (no new Logic state).
- Night is a deliberate interstitial; then define what ends it / begins the next turn (a "Continue" gate, or a Presentation-only tween/animation that must NOT advance the sim clock — see no-timer rule below).

## Queue-empty precondition (conflict with the feature)

End Turn is blocked while the farmer has pending actions, enforced at **two** layers:

- Logic: `advance_simulated_turn()` first guard — `if has_pending_actions(): return _fail("Wait for the farmer to finish queued actions before advancing time.")` (`farming_controller.gd:206`).
- Presentation: `next_turn_button.disabled = ... or farming_controller.has_pending_actions()` (`field_prototype_presenter.gd`, `_on_action_queue_changed`).

Queued actions commit on farmer **arrival during day** (`action_finished`, `arrive_at_action`), not during night. By the time End Turn is pressable, the queue is drained.

**Feature conflict:** `day_night_cycle.feature` scenario "Queued farmer actions commit before night completes" (Given queued actions + When the player ends the turn) describes a state the UI and Logic both prevent. It also contradicts `treatments.feature` ("Next Turn is disabled" while a treatment is queued). Reconcile before implementing: reword to the existing drain-then-end flow, or change the gating design and update `treatments.feature` + the presenter + `advance_simulated_turn`'s guard together.

## Day/night rendering — greenfield

There is **no** day/night, lighting, or time-of-day visual anywhere in `src/presentation/`. Existing overlays: `_start_overlay`, `_end_overlay` (game over), crop/selection/grass/fence layers. Implementing the visual side is new work; a `CanvasModulate`/lighting or a dedicated overlay driven by `turn_completed` is the likely shape. Keep it Presentation-only (structure rule: Simulation has no scene dependencies).

## Game-over interaction

`check_turn_limit()` runs inside `advance_turn()` **after** `turn_index` increments and **before** `turn_completed.emit`. At the limit it fires `transition_to(GAME_OVER)` + `game_ended.emit(false)`, and the presenter shows `_end_overlay` ("Game Over — Out of turns…"). `turn_completed` still emits on the losing turn. The feature has no scenario for the final/losing turn's day/night state or whether End Turn remains available at the limit — add one.

## Conventions that bind this feature

- **No timers drive simulation.** Presentation-only tweens/animations for the day↔night transition are fine; they must not mutate `turn_index` or the grid. (Currently only farmer *movement* animation is called out in the feature; the transition animation needs the same guarantee.)
- **Copy-on-stage / validate-don't-throw.** A rejected End Turn leaves grid, RNG, counters, and clock unchanged and sets `last_error` — already true in `advance_turn()`. "Failed turn end preserves state" is grounded.
- **Observers after commit.** Any new day/night signal must emit after the turn is committed, not before.
- **Seeded RNG streams stay independent.** Determinism scenario is supported by seeded RNG + discrete `turn_index`; "same day or night state" is effectively turn-index parity — consider strengthening the assertion.

## Testing approach

No dedicated `turn_controller_test.gd` exists. Turn behavior is exercised in:
- `tests/logic/disease_activation_test.gd` — `TurnController` fixture, `advance_turn()`, `turn_index`, connects to `turn_completed`, asserts "Notification sees committed clock".
- `tests/logic/simulation_scaffold_test.gd` — `turn_completed` probe, "Growth -> Simulation -> UI", invalid catalog rejected with `turn_index` unchanged and no partial growth.

Pattern to follow: build a `TurnController` fixture, connect to `turn_completed`, assert `advance_turn()` bool + `turn_index`, and assert no partial state on rejection. New day/night tests should live in `tests/logic/` (clock/turn behavior) and `tests/presentation/` (visual state), per the layer split in `testing-guidelines.md`.

## Open decisions before implementation

1. Night = flash vs. interstitial (see Turn flow). Determines whether new Logic state/signal is needed.
2. Reconcile the queued-actions conflict (see above) across feature + code.
3. Add save/load scenario: what does an older save (no day/night phase) restore as? `turn_index` already persists; night-as-derived restores automatically, night-as-interstitial does not.
4. Add a game-over / final-turn scenario.
