# Design: Infected Debris Chance After Harvest

Status: Proposed, pending the decisions in [requirements.md](requirements.md). Implementation work is listed in [tasks.md](tasks.md).

## Verified current behavior

- `FarmingController.harvest_crop` validates the target, captures crop type and quality, copies the grid, clears the crop with `reset_crop_state()`, and commits the copy.
- `arrive_at_action` checks queue order, validity, and revisions before dispatching harvesting. It emits `queued_harvest_completed` for the presenter to forward to `GameStateManager.record_harvest`.
- `FieldCellState.validate()` prohibits active crop disease and nonzero compartment fractions on empty cells. `copy()` explicitly copies each field.
- No debris state or chance policy exists in the inspected implementation. This document describes future changes, not completed functionality.

## Layer responsibilities and proposed files

| Layer | File or component | Proposed responsibility |
|---|---|---|
| Data | `src/data/state/field_cell_state.gd` | Add `has_infected_debris`, initially false; copy and validate approved metadata separately from crop disease fields. |
| Data | `src/data/resources/infected_debris_policy.gd` (new) | Passive chance/seed configuration and validation; schema finalized by D1–D3. |
| Logic | `src/logic/farming/infected_debris_resolver.gd` (new) | Resolve approved eligibility and probability against pre-harvest state using a caller-supplied draw; no live-grid mutation. |
| Logic | `src/logic/farming/farming_controller.gd` | Own a dedicated seeded RNG; stage, validate, and commit harvest and debris atomically. |
| Data/Logic | Existing cell operations and initialization | Apply D4 lifecycle rules explicitly; preserve copy/reset semantics and transactional initialization. |
| Presentation | Existing world view, inspector, and presenter, if selected by D5 | Display committed debris from snapshots without generating outcomes or mutating cells. |

Dependencies remain Presentation → Logic → Simulation → Data. The chance rule does not require a new Simulation model. No new singleton, autoload, or action enum is proposed. Preserve `HarvestResult` unless an approved presentation requirement establishes a need to extend it.

## State and lifecycle

Use debris state separate from `has_crop`, `has_active_disease`, `active_disease_id`, and compartment fractions. A harvested cell can therefore be empty with debris while still satisfying existing crop invariants.

The proposed minimum representation is a boolean. D3 may require additional passive metadata, copied by value or deep copy as appropriate. Do not assume a crop's default disease ID identifies debris after crop reset.

Capture eligibility and any approved metadata before `reset_crop_state()`. Set the debris outcome explicitly on the candidate afterward. Do not add unconditional debris clearing to that shared reset method: planting, moving, removal, and fencing also use crop-state operations. Audit those callers against D4 before implementation. Grid snapshots and ordinary turn copies must not accidentally lose debris; intentional expiry requires an approved lifecycle rule.

New field cells start clear. Stage RNG initialization alongside successful field initialization so a failed new-field attempt cannot alter the previous session's random sequence. Persistence across save/load is outside scope because current Continue does not restore field state.

## Chance contract

The resolver receives a pre-harvest snapshot and a validated policy. Eligibility remains an explicit unresolved predicate until D1 is approved; do not infer it from only one disease representation.

For eligible crops, use `u < p`. The proposed sampling convention consumes exactly one draw for every eligible committed harvest, including p = 0 and p = 1, and none for ineligible harvests. This convention extends the draft scenarios and must be captured in T1 acceptance updates. Ensure the generator produces values in [0, 1); do not assume an API with an inclusive upper endpoint satisfies this contract. Tests inject exact draw values rather than relying on statistical frequency assertions.

The controller owns the debris RNG independently of other streams. Clone its state into a temporary generator for each proposed harvest; only copy the advanced state back after successful candidate validation. A pure resolver makes boundary tests independent of engine seed sequences.

## Harvest transaction

1. Preserve queue-order, reservation, revision, maturity, catalog, and field checks. Validate the debris policy before any draw or live mutation.
2. Read the original cell's crop identity, quality, eligibility, and any approved debris metadata.
3. Copy the grid and debris RNG state into staged objects.
4. For an eligible crop, resolve one staged draw. For an ineligible crop, skip the draw and debris creation.
5. Clear the candidate crop and apply the approved debris outcome and lifecycle rules.
6. Validate the candidate, including debris invariants and existing terrain/crop rules.
7. On failure, discard staged objects, return an unsuccessful result with a reason, and retain all authoritative state.
8. On success, commit the candidate grid and staged RNG state, then issue the existing cell-change notification and successful result.

Queued execution continues through the existing completion signal and score handler. Direct calls to `harvest_crop` use the same transaction but must not introduce a second score path. Invalid arrivals cannot reach the resolver. Presentation callbacks must observe the fully committed grid; reaching the harvest goal must not interrupt debris commit.

## Configuration and presentation dependencies

Use an exported policy reference consistent with existing Inspector wiring. Validate required policy configuration before accepting dependent operations, and expose errors through established validation and `last_error` conventions. D2 must settle defaults and whether a single probability suffices before creating an authored resource.

D5 must specify the actual indication before selecting assets or scene changes. Preserve authored assets and references. If resources or scenes need wiring, use the Godot Editor or established editor tools; do not hand-edit `.tscn` or `.tres`. The current Gherkin promise of a visible consequence is a known specification gap, not proof of an implemented visual requirement.

## Verification design

Follow [testing guidelines](../../../.agents/testing-guidelines.md). Write meaningful checks with the relevant implementation tasks and register executables in `tools/run_tests.py`; execute them once in the final verification phase.

- Resolver: exact threshold table, endpoints, ineligible no-draw behavior, invalid/non-finite policy values, and each approved eligibility state.
- State: detached cell/grid copies, metadata invariants, initialization, and D4 lifecycle behavior.
- Logic: farmer-arrival timing, stale/rejected/duplicate requests, quality and score preservation, victory-threshold harvest, no turn advance, and unchanged neighboring cells.
- Atomicity: force a post-draw candidate failure; verify field, RNG, counters, and clock remain unchanged and the next valid harvest matches a control sequence.
- Determinism: replay equal seeds and harvest sequences; vary unrelated RNG activity and confirm debris outcomes stay equal.
- Presentation, only after D5: verify committed updates and approved visuals/input interactively; headless tests alone cannot establish appearance or Android behavior.

Reuse `gameplay_test_fixture.gd` and `queued_action_test_driver.gd`. Do not add a new BDD framework solely to execute these feature documents.
