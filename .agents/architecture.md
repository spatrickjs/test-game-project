# Architecture and constraints

Preserved from `.kiro/steering/{structure,tech}.md` and inspected implementation. These are existing project constraints, not a proposed redesign.

## Layers

Dependencies point downward: **Presentation → Logic → Simulation → Data**. Lower layers must not depend on higher layers; shared Data types may be consumed directly.

| Layer | Path | Responsibility |
|---|---|---|
| Data | `src/data/` | Enums, passive RefCounted state, authored Resources, catalogs. |
| Simulation | `src/simulation/` | Model calculations and neighborhood geometry; no scene, Logic, or Presentation dependencies. |
| Logic | `src/logic/` | Authoritative mutable state, action validation/commit, turn coordination, menu state/persistence. |
| Presentation | `src/presentation/` | Views, input, rendering, and composition-root presenters that connect intents to Logic. |

## Ownership and behavior

- `FarmingController` owns the live grid. Expose detached `copy()` snapshots; views send intents and never mutate authoritative state.
- Stage changes on copies, validate, then commit. Failure must preserve authoritative state, RNG, counters, and clock; notify observers after committed changes.
- Simulation reads a start-of-turn snapshot. Keep simulation, disease-activation, and decoration RNG streams independent and seeded.
- Simulation advances through manual turns, not timers/frame callbacks. Preserve queued farmer actions and arrival-time commits; movement animation does not advance the simulation clock.
- Data holds no rendering IDs; existing `CropData` growth-visual fields are the presentation-only exception.

## Project conventions

- Use typed GDScript variables, parameters, and returns. Preserve nearby naming/style without unrelated reformatting.
- Validation returns `PackedStringArray` (empty means valid); rejected operations expose `last_error`. Reuse existing validation and copy APIs.
- Wire exported references in the Inspector; do not replace them with hardcoded node paths. Retain view `validate_configuration()` and presenter reference validation, plus `_connect_once` signal wiring.
- Enum numeric values are save-stable: append, never reorder existing values.
- Do not hand-edit `.tscn`/`.tres`. Preserve user-authored scenes; use the Godot Editor and established editor setup tools only when the task requires those changes. Do not rerun setup for ordinary launch; some tools overwrite tuned resources.
- New global state/autoloads require an explicit design decision approved by the user.

For concrete module locations and current configuration, see [repo-findings.md](../repo-findings.md).
