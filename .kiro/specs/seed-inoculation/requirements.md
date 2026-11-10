# Seed inoculation requirements

## Scope and sources

Implement the game mechanic described by `features/seed_inoculation.feature`, `features/inoculation_simulation_impact.feature`, and `features/seed_inoculation_ui.feature`. This specification covers runtime crop protection, queued player actions, simulation integration, and UI feedback on the existing 9x6 field.

## Acceptance requirements

- **R1 — Application:** Given an occupied eligible cell with adequate soil moisture, committing an Inoculate action shall activate protection. Seedling and Vegetative applications shall reduce recipient susceptibility by 25%; Mature applications shall reduce it by 15%. Verify the feature examples at (2,1), (4,3), and (0,5).
- **R2 — Validation:** Out-of-bounds, empty, missing-soil, or inadequately moist targets shall be rejected without changing the field. The tile inspector shall show the rejection reason. Validation shall occur both when queuing and at commit.
- **R3 — Queue integration:** Inoculation shall use existing FIFO reservations, copied requests, revision checks, farmer arrival, and failure cleanup. Enqueueing shall not apply protection. A successful commit shall be recorded as a valid farming action; it shall not advance the turn. Next Turn shall remain blocked while actions are pending.
- **R4 — Transmission:** Spatial SIR and Spatial SEIR shall apply protection to the recipient's effective transmission coefficient exactly once. With otherwise identical inputs, positive pressure, and uncapped coefficients, treated effective beta shall equal untreated beta multiplied by 0.75 or 0.85 at initial efficacy. At zero pressure or saturation, require non-increasing infection risk rather than strict inequality. Existing compartment invariants shall hold.
- **R5 — Duration:** Protection shall survive turn advancement until its configured duration or efficacy reaches zero. Each successful turn shall apply weather-dependent decay exactly once. Expiration shall restore the neutral transmission multiplier of 1. Failed turns shall not age protection.
- **R6 — Lifecycle:** Detached snapshots shall preserve protection without shared mutable state. Moving a crop shall preserve protection; harvesting, removing, or replacing it shall clear protection. Empty cells shall never retain active protection.
- **R7 — Tool:** The toolbar shall expose Inoculate, map selection to `TOOL_INOCULATE`, and display an applicator cursor. Existing input cancellation and queue behavior shall apply.
- **R8 — Inspector:** Selecting a protected crop shall display `Inoculated: Active`, remaining protection turns, and its current resistance bonus percentage. Expired/untreated crops shall display an inactive status without stale values.
- **R9 — Overlay:** Enabling the crop debug/status overlay shall show a subtle protection icon or aura only on actively protected crops, based on detached snapshots. Changes and expiration shall refresh the overlay.
- **R10 — Compatibility:** Neutral protection defaults shall preserve existing untreated behavior and existing enum identifiers. All shared transmission evaluator callers shall remain compatible.

## Proposed decisions where features are incomplete

These are implementation defaults, not facts specified by the source features. Keep them configurable and verify them in tests.

- Duration: 3 successful simulation turns, including the first transition after application.
- Adequate moisture: inclusive normalized range [0.3, 1.0].
- Weather decay: configurable nonnegative reduction in bonus per turn, default 0 percentage points for every weather condition until balancing values are supplied. Duration still expires normally.
- Apply decay after that turn's transmission. Freeze the initial stage bonus at application; subsequent growth does not replace it.
- Reapplication refreshes duration and replaces the bonus using the current stage; bonuses do not stack.
- Seeds refer to planted crops in the existing lifecycle; inventory seed treatment is outside scope. Map any additional living growth stage to the pre-mature 25% rule. Reject fully dead/removed crops.
- Protection reduces new infection only; it does not cure existing infection.
- Since the transmission evaluator is shared, use the same recipient factor for the stochastic CA model and verify neutral behavior there as well.

## Feature clarification

The duration scenario contains `<turn_count>` in a plain Scenario without Examples. During implementation, convert it to a Scenario Outline with explicit boundary examples or replace the placeholder with concrete steps. Add SEIR coverage: the impact feature names SEIR but currently exercises only SIR. Replace “significantly lower” with the deterministic checks in R4.
