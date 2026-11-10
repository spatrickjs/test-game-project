# Requirements: Infected Debris Chance After Harvest

Status: Draft specification. Authoring these documents does not approve unresolved gameplay decisions or implement the feature.

## Purpose and scope

An eligible successful harvest can leave infected debris on the harvested tile. This is a fictional educational game mechanic, not a calibrated agricultural prediction. Preserve queued farmer actions, existing harvest quality and scoring, and manual turn advancement.

Acceptance sources:

- [Chance scenarios](../../../features/infected_debris_chance.feature)
- [Harvest integration scenarios](../../../features/infected_debris_harvest_integration.feature)

These sources remain tagged `@draft`. Requirements R1–R4 capture their proposed behavior; R5–R6 add architectural safeguards and configuration contracts for review.

## Terms

- **Eligible crop:** A harvested crop satisfying the rule to be decided in D1. This is not yet synonymous with `has_active_disease`, categorical I, or a positive infected fraction.
- **Debris:** Separate tile state created by this feature, not an occupied crop or an active crop-disease compartment.
- **Chance p:** A configured finite probability in [0, 1].
- **Draw u:** A controlled random value in [0, 1).
- **Successful harvest:** A committed crop removal producing a successful `HarvestResult`.

## Open decisions

| ID | Decision needed before implementation | Why it matters |
|---|---|---|
| D1 | Define eligibility across categorical and continuous disease models, including exposed, recovered, and dead states. | Determines which pre-harvest cells receive a chance evaluation. |
| D2 | Choose the default probability and seed, and whether probability varies by crop or disease. | Determines policy schema and authored configuration; 0.25 in Gherkin is only a test input. |
| D3 | Decide whether debris retains disease identity or other metadata. | Determines passive state and validation requirements. |
| D4 | Define debris lifetime and interactions with turns, planting, moving crops, shovel, fencing, terrain conversion, and subsequent harvests on debris-bearing tiles. | Prevents accidental clearing, copying, or blocking through existing cell operations. Current scenarios start without debris. |
| D5 | Decide the minimum player-visible indication, approved art if any, and inspector/status wording. | The user story promises visibility, but existing scenarios specify no presentation contract. |

Record decisions here, then update design, tasks, and Gherkin together. Transmission effects, cleanup tools, and planting restrictions are not implicitly authorized by the word “infected.” Any selected gameplay extension needs explicit acceptance criteria.

## Requirements

### R1 — Chance resolution

1. On an eligible successful harvest from a tile without debris, evaluate the debris chance exactly once using the pre-harvest crop state.
2. Create debris on that tile if and only if `u < p`.
3. At p = 0, never create debris; at p = 1, always create debris. At u = p, do not create debris.
4. An ineligible successful harvest creates no debris and performs no debris chance evaluation.

### R2 — Queue and rejection behavior

1. Queuing a harvest must not mutate the tile or evaluate the chance. A queued harvest resolves at valid farmer arrival.
2. Preserve existing rejection of empty, immature, out-of-field, and reserved targets.
3. A stale queued action must cancel without further field changes or chance evaluation.
4. Duplicate or outdated arrivals must not repeat harvesting, scoring, or chance evaluation.

### R3 — Preserve harvest semantics

1. Both debris outcomes remove the crop while preserving the harvested tile's terrain and soil and leaving other tiles unchanged.
2. The result retains the harvested crop identity, target coordinates, and quality multiplier `1 - pre-harvest yield_quality_loss`.
3. The existing queued completion path increments the successful harvest count exactly once, including when that harvest reaches the victory goal.
4. Harvest and debris creation must not advance the turn index.
5. Empty tiles must retain existing cleared crop lifecycle, disease, and compartment invariants; debris must not bypass these invariants.

### R4 — Determinism

1. Identical initial fields, policies, seeds, and eligible harvest sequences produce identical debris outcomes.
2. Debris randomness must be independent of simulation, disease activation, and decoration random streams.
3. Queuing, rejection, cancellation, and duplicate arrivals must not consume debris randomness.

### R5 — State ownership and atomicity

1. Logic owns authoritative debris state; presentation consumes detached snapshots.
2. Copying a cell or grid preserves debris values without sharing mutable metadata.
3. Crop removal and debris outcome commit together after candidate validation. A failed operation preserves field state, debris RNG state, counters, and clock, and emits no successful harvest notification.
4. Notify observers only after committed state is available.
5. A newly initialized field starts without debris; successful session initialization resets the debris stream to the configured seed. Failed initialization preserves the previous session state.
6. Other cell operations must follow the D4 lifecycle contract once it is specified; do not infer that crop reset also means debris removal.

### R6 — Configuration validation

1. Reject non-finite probabilities and values outside [0, 1]; do not silently clamp them.
2. Report invalid policy configuration through existing validation/error conventions without state or RNG mutation.
3. Do not ship a placeholder probability or seed as an approved gameplay default.

## Non-goals

No disease-spread model changes, scientifically calibrated parameters, inventory/currency rewards, new action kinds, autoloads, save-game restoration, or automatic turn advancement. Visual implementation and lifecycle interactions require D4/D5 acceptance criteria before inclusion.

## Acceptance traceability

| Gherkin scenario | Requirements |
|---|---|
| Resolve the configured chance on successful harvest | R1, R3 |
| Ineligible harvest does not create infected debris | R1, R4 |
| Repeat a harvest sequence deterministically | R4 |
| Queuing a harvest does not resolve debris | R2, R4 |
| Farmer arrival resolves debris on the harvested tile | R1, R2, R3 |
| Debris outcome preserves the harvest result | R3 |
| Rejected harvest does not resolve debris | R2, R4, R5 |
| A stale queued harvest does not resolve debris | R2, R4, R5 |
| Duplicate arrival does not repeat debris resolution | R2, R4 |

Add acceptance scenarios for R5–R6 and resolved D1–D5 in task T1; do not represent those additions as already present in the feature files.
