---
inclusion: always
---
# Structure

Four layers. Dependencies point downward only: Presentation -> Logic -> Simulation -> Data.

| Layer | Path | Owns |
|---|---|---|
| Data | `src/data/` | enums, state (`RefCounted`), resources, catalogs |
| Simulation | `src/simulation/` | pure models, `SimulationController`, geometry |
| Logic | `src/logic/` | mutable state owners, controllers, turns, menu logic |
| Presentation | `src/presentation/` | views, presenters, world rendering |
| Tests | `tests/{logic,simulation,presentation,menu}/` | SceneTree scripts |

Rules:
- `FarmingController` owns the live grid. Others get detached `copy()` snapshots.
- Presenters are composition roots. Views emit intents; they never mutate state.
- Simulation has no scene, Logic, or Presentation dependencies.
- Data layer holds no rendering IDs except `CropData` growth visuals (presentation-only fields).
- Do not read the whole tree. Open only the layer you are changing.
