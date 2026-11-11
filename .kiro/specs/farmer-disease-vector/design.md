# Design — Farmer as Disease Vector

Traces to [requirements.md](requirements.md) (R1–R14).

## Current implementation

| Component | Relevant behavior |
|---|---|
| `FarmingController.arrive_at_action` | Validates the queue head and plot revisions. A crop move's source arrival updates queue progress, and delivery commits the action. Several dispatched methods publish cell changes internally. |
| `FarmingController.advance_simulated_turn` | Stages a grid copy and validates before replacing the live grid. `TurnController.advance_turn` increments the clock after success. |
| `DiseaseActivationController` | Owns seeded RNG state and exposes detached snapshots and a commit API. Activation evaluation also tracks automatic introductions. |
| `FieldCellState` | A fenced tile is empty grass. Active protection on a planted plot is a separate treatment-state query. |

## Proposed gameplay decisions

- Evaluate the action's target at the final commit stop. Read its infection status before the action so harvesting or removing an infected crop can contaminate the farmer. Use the staged post-action target for transmission eligibility so a removed crop cannot be infected. Crop-move pickup is a movement waypoint.
- Carry one disease ID. A committed contact with an infected target replaces the carried ID and refreshes the duration. Use a positive infected fraction and an active disease ID to classify contact.
- Use one draw for an eligible target, including chance settings of 0 and 1. Use the treatment controller's active protectant state, including any protection applied by the staged action. Preserve existing fence behavior for neighboring plots.
- Expose a probability in `[0, 1]` and a positive integer duration through typed Logic configuration. The implemented fictional defaults are 0.25 and three completed turns.

## Components

### Logic — FarmingController

Own the carried disease and remaining turns. Reset both when initializing a session. Expose a scalar contamination query for Presentation and continue returning detached grid snapshots (R1, R10, R14).

For a final arrival, stage the queued action and farmer effects together. Include any grid, treatment, harvest, or revision updates the action would normally produce. Reuse existing validation and action rules through staging entry points where current helpers commit directly. Keep normal direct callers' behavior. Resolve pickup from the pre-action target and check transmission eligibility on the candidate grid. Reuse disease catalog compatibility and infection initialization, including validation against the active simulation configuration (R1–R3, R6, R11–R12).

Validate the candidate before assigning authoritative state. Publish cell and successful action notifications after assigning the grid, contamination, RNG state, and action effects. Preserve the existing rejection result and queue lifecycle notifications on failure. Those signals report queue progress and failure, while committed-state observers see only successful mutations (R7–R9).

### Logic — DiseaseActivationController and TurnController

Use a temporary RNG initialized from the detached activation snapshot. Stage the advanced RNG state even on a valid missed roll, and commit it only with a successful action. Preserve automatic introduction history, cooldown, and counters. Keep the simulation and decoration streams out of this path. Supply the existing activation, catalog, and simulation dependencies from the current composition path (R2, R4–R5).

Decrement remaining contamination once per successful manual turn, before turn-completed observers read state. Clear the carried disease when the count reaches zero. Movement, queued actions without infected contact, and failed turns leave the count unchanged (R6, R13).

### Presentation

Keep the existing arrival callback and committed-cell rendering path. Read the contamination query when needed. The feature requires data availability and leaves visual treatment out of scope (R9, R14).
