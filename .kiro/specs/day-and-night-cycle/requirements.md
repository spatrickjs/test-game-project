# Day and night cycle — requirements

Source: `features/day_night_cycle.feature`. Context: `repo-findings` (day-night). Constraints: `architecture.md`.

## Scope

- Night is a Presentation-only phase shown after End Turn commits.
- Day is the default phase.
- Non-goals: new Logic or Simulation state, new signals, autoloads, save-format changes, gameplay effects of night.

## Requirements

| ID | Requirement | Scenarios |
|---|---|---|
| R1 | A new game starts in day. | New game starts in day |
| R2 | Day persists during actions and real time; the turn index changes only on committed turns. | Day persists while the player acts; Real time passing does not trigger night |
| R3 | Next Turn is disabled while farmer actions are pending; queued actions commit on arrival during day. | End Turn is unavailable…; Pending actions commit during day… |
| R4 | After a committed turn, the view transitions to night, triggered by `turn_completed`. | Ending the turn shows night |
| R5 | Night ends when its transition animation completes; the scene returns to day and the player may act again. | Night ends when its transition completes |
| R6 | Day/night and movement animations never mutate `turn_index`, grid, RNG, or counters. | Day and night transitions…; Farmer movement… |
| R7 | The Simulation layer has no night concept; night is view state only. | Night is a presentation state only |
| R8 | A rejected turn end leaves the phase as day and state unchanged; `last_error` is set. | Failed turn end preserves state |
| R9 | On the final turn, night is shown, then game over; End Turn is not offered afterward. | Turn limit reached |
| R10 | Loading a save (including older saves) starts in day at the saved `turn_index`. | Loading a save…; Older save… |
| R11 | Same seed and same turn count give the same turn index and phase. | Same seed gives… |

## Resolved decisions

- Night is an interstitial ended by the animation, not by a Continue gate.
- Phase is not persisted.
- Next Turn is disabled during night. Other input is unchanged unless the user decides otherwise.

## Open questions

- Should farmer actions be blocked during night?
- Does the game-over overlay wait for the night transition? Default: yes (R9).
