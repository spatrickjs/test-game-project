# Action Bar: Requirements

Source: `features/action_bar.feature` (authoritative acceptance criteria). Constraints: `.agents/architecture.md`.

## Decisions (resolved from open questions)

- Owner: `FarmingController`. No new class, autoload, or Resource.
- Default maximum 5 (script constant); no upper bound.
- Applies to every farmer action type that commits via `arrive_at_action`.
- Consumption at commit, not enqueue. Enqueue rejects only when 0 remain.
- Not saved/loaded. Starts full on a new game.
- Per-type limits, difficulty modes: out of scope.

## Requirements

| ID | Requirement | Scenarios |
|---|---|---|
| R1 | New game: remaining = maximum = 5. | starts full |
| R2 | `try_set_max_actions(n)` accepts n >= 1; new game starts full at that maximum. | swappable maximum |
| R3 | n <= 0 is rejected; `last_error` reports invalid maximum; maximum and count unchanged. | invalid maximum |
| R4 | Raising maximum keeps count. Lowering clamps count to min(count, new max). | raise / lower / lower-above-count |
| R5 | Each committed action consumes exactly 1; one observer notification per consumption. | each action consumes one |
| R6 | At 0 remaining, enqueue and arrival reject with `last_error` reporting insufficient actions; grid, RNG, counters, clock, bar unchanged. | empty bar |
| R7 | Invalid action rejected without consuming. | invalid action |
| R8 | Count stays within [0, maximum] under any adjustment. | never exceeds / never below zero |
| R9 | Queued action consumes at arrival commit. Failed arrival validation leaves bar and authoritative state unchanged. | queued / failed commit |
| R10 | Movement does not consume. | movement |
| R11 | Successful turn commit resets count to the current maximum (including one changed mid-turn); observers notified after commit. | end-turn reset, mid-turn max, available after reset |
| R12 | No reset without turn commit. Rejected turn keeps bar, grid, RNG, counters, clock; `last_error` set. | no reset / failed end turn |
| R13 | HUD shows "remaining of maximum" and updates from signals; never mutates the bar. | (not in feature; see non-goals) |

## Non-goals

- Persistence, per-type costs, refunds on gameplay events, new autoloads.
- Hand-editing `.tscn`/`.tres`.
- R13 HUD node authoring beyond a documented scene dependency.
