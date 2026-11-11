# Day and night cycle — design

Requirements: `requirements.md`. No new Logic or Simulation code (R7).

## Layer impact

| Layer | Change |
|---|---|
| Data | none |
| Simulation | none |
| Logic | none. `TurnController.turn_completed(turn_index)` is the trigger. |
| Presentation | new `DayNightView`; wiring in `FieldPrototypePresenter` |

## Components

**`DayNightView`** — new, `src/presentation/world/day_night_view.gd`.
- Owns a full-field tint or `CanvasModulate`, and one tween.
- API: `show_day()` (instant reset), `play_night_transition()`, `is_night() -> bool`.
- Signal: `night_finished`, emitted when the night-to-day transition completes.
- Exported references wired in the Inspector; `validate_configuration()` returns `PackedStringArray`.
- Holds no reference to Logic or Simulation. It never touches the turn index.

**`FieldPrototypePresenter`** — existing composition root.
- Validates the new view reference alongside existing references.
- `_connect_once`: `turn_controller.turn_completed` → start night; `day_night_view.night_finished` → leave night.
- Next Turn gating: extend the existing button-state function with an "is night" condition.
- Game over: defer showing `_end_overlay` until `night_finished` when the game ended on that turn (R9).
- New game and Continue paths call `show_day()` (R1, R10).

## Flow

1. Player presses Next Turn. `advance_turn()` commits and emits `turn_completed`.
2. Presenter calls `play_night_transition()`. Next Turn is disabled.
3. The view finishes. `night_finished` fires; the presenter re-enables controls via the existing gating function.
4. If the game ended, the presenter shows `_end_overlay` instead of re-enabling.

## Constraints

- Tween only; no timers drive the simulation. The view cannot reach the clock.
- Rejected `advance_turn()` emits nothing, so the view stays in day (R8).
- No `.tscn` hand edits. The scene node and Inspector wiring are an Editor task (T3).

## Risks

- The `_end_overlay` trigger path was not inspected. Read `field_prototype_presenter.gd` around `game_ended` before T2.
- The load path location is unverified. Locate it before T2.
