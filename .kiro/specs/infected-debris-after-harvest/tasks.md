# Tasks: Infected Debris Chance After Harvest

Status: Specification authored; gameplay implementation has not started. All implementation tasks remain unchecked. See [requirements.md](requirements.md) and [design.md](design.md).

## Dependency graph

```mermaid
flowchart TD
    T1["T1 Resolve decisions and approve contracts"]
    T2["T2 Passive debris state and policy"]
    T3["T3 Eligibility and chance resolver"]
    T4["T4 Atomic harvest and RNG integration"]
    T5["T5 Lifecycle and session integration"]
    T6["T6 Approved presentation and wiring"]
    T7["T7 Integration coverage and test registration"]
    T8["T8 Final verification and handoff"]
    T1 --> T2
    T2 --> T3
    T3 --> T4
    T4 --> T5
    T5 --> T6
    T4 --> T7
    T5 --> T7
    T6 --> T7
    T7 --> T8
```

The graph is an execution dependency graph, not an instruction to spawn agents. T6 is conditional: if presentation is explicitly deferred at T1, record the remaining visibility gap and satisfy the T6 gate by documenting that deferral. Do not report a fully visible feature as complete in that case.

| Task | Depends on | Requirement coverage |
|---|---|---|
| T1 | — | D1–D5; acceptance additions for R4–R6 |
| T2 | T1 | R5, R6 |
| T3 | T2 | R1, R4, R6 |
| T4 | T3 | R1–R5 |
| T5 | T4 | R5, approved D4 |
| T6 | T5 | Approved D5 |
| T7 | T4, T5, T6 | R1–R6 and approved extensions |
| T8 | T7 | Final evidence for all accepted criteria |

## Implementation checklist

- [ ] **T1 — Resolve gameplay decisions and approve the implementation contract**
  - [ ] Record D1 eligibility across all supported disease representations.
  - [ ] Record D2 probability scope/default and seed; D3 metadata; D4 lifecycle/interactions; D5 visual scope or explicit deferral.
  - [ ] Confirm the proposed one-draw convention at probability endpoints and configuration validation behavior.
  - [ ] Extend Gherkin for state copying, rollback, RNG isolation, initialization, invalid configuration, and selected lifecycle/presentation rules.
  - [ ] Reconcile requirements/design with those decisions and obtain approval for the cross-layer implementation before coding. The current request authorizes spec files only.

- [ ] **T2 — Add passive state and policy, with focused tests**
  - [ ] Add the approved debris fields to `FieldCellState`; update detached copying and validation.
  - [ ] Define the policy resource with approved defaults and finite [0, 1] probability validation.
  - [ ] Write state-copy, metadata-invariant, and invalid-policy tests; do not execute them yet.

- [ ] **T3 — Implement eligibility and chance resolution, with focused tests**
  - [ ] Add a resolver that uses pre-harvest state, the approved policy, and a supplied draw without mutating the live field.
  - [ ] Cover exact probability boundaries and every approved eligibility class.
  - [ ] Specify and test the sampling adapter's [0, 1) range and approved draw-count convention.

- [ ] **T4 — Integrate an atomic harvest transaction, with focused tests**
  - [ ] Add a separate seeded debris RNG owned by `FarmingController`.
  - [ ] Stage crop removal, debris, and RNG state; validate before committing and notifying observers.
  - [ ] Preserve existing queue validation, stale/duplicate arrival handling, receipt quality, scoring, and turn behavior.
  - [ ] Write farmer-arrival, direct-harvest, rejection, victory-threshold, and post-draw rollback tests using existing fixtures.

- [ ] **T5 — Integrate lifecycle and initialization, with focused tests**
  - [ ] Audit `reset_crop_state`, cell/grid copies, turn staging, planting, movement, removal, fencing, and conversion against D4.
  - [ ] Apply only approved lifecycle changes; add regression coverage for affected operations.
  - [ ] Initialize fresh fields without debris and reset the dedicated seed on successful initialization only.
  - [ ] Cover failed initialization and deterministic replay without perturbing other random streams.

- [ ] **T6 — Implement approved presentation and resource wiring**
  - [ ] Apply D5's indication through existing views/presenters consuming detached committed state, or record the approved deferral.
  - [ ] If required, wire policy/assets through the Godot Editor or established tools while preserving authored references.
  - [ ] Write relevant presentation checks and an interactive verification checklist for the approved scope.

- [ ] **T7 — Complete acceptance coverage and register tests**
  - [ ] Map each Gherkin scenario and R1–R6 criterion to concrete tests or a documented interactive check.
  - [ ] Register new test executables in `tools/run_tests.py`; reuse current fixtures and conventions.
  - [ ] Review rollback, RNG isolation, duplicate notifications, and unchanged neighboring tiles across the full integration.
  - [ ] Finish all implementation and test authoring before executing the suite.

- [ ] **T8 — Perform the single final verification phase and handoff**
  - [ ] Import project/assets in a compatible Godot editor, then run `python tools/run_tests.py --godot '<installed Godot executable>'` once.
  - [ ] Require exit zero, `_PASS` markers, and no error, warning, or failure diagnostics; fix failures and rerun affected checks as needed.
  - [ ] Complete acceptance-focused interactive checks if visuals/input changed; document unavailable Android verification.
  - [ ] Review spec/Gherkin traceability and report commands, results, environmental blockers, and remaining gaps.
  - [ ] Mark only verified tasks complete and update owning documentation if implementation changes established facts.

## Specification-only verification

For the current request, review relative links, requirement/task coverage, and graph consistency. No game test run is needed for these Markdown-only additions. None of the unchecked tasks above is completed by creating this specification.
