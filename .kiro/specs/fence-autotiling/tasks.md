# Tasks — Fence Auto-tiling

Each task is sized for a fresh context: read only the listed files, touch only the listed files.

## Dependency graph

```
Wave 1:  T1 ─────────┐      T2 ──────┐
                     │              │
Wave 2:              ├─► T4 ◄───────┤      T3 ◄── T2
                     │              │
Wave 3:              └──────► T5 ◄──┴──── T3, T4
                              │
Wave 4:                       T6
```

- Wave 1: T1, T2 in parallel.
- Wave 2: T3, T4 in parallel (T3 needs T2; T4 needs T1, T2).
- Wave 3: T5.
- Wave 4: T6.

## Table

| ID | Task | Depends on | Reads | Writes | Reqs |
|---|---|---|---|---|---|
| T1 | Add `fence_connections` and `fence_shape` to Simulation, with unit tests | — | `src/simulation/.../field_grid_queries.gd`, `field_cell_state.gd` | `field_grid_queries.gd`, `tests/simulation/fence_connections_test.gd` | R1, R2, R5, R6 |
| T2 | Extend `FenceVisual`: mask→tile mapping, `validate`, `make_icon` | — | `fence_visual.gd` | `fence_visual.gd` | R7, R8, R9 |
| T3 | Extend `setup_fence_tool.gd`: author 16 tiles, populate mapping; run in editor | T2 | `setup_fence_tool.gd`, `setup_crop_growth_visuals.gd`, `fence_visual.gd` | `setup_fence_tool.gd`, `fence_tile_set.tres`, `fence_visual.tres` (via tool) | R7 |
| T4 | Make `render_fences` neighbor-aware | T1, T2 | `field_world_view.gd` (render_fences region), `fence_visual.gd` | `field_world_view.gd` | R3, R4, R7, R9 |
| T5 | Presentation tests: per-mask atlas coords, place/remove repaint | T3, T4 | `fence_presentation_test.gd` (template) | `tests/presentation/fence_autotiling_test.gd` | R3, R4, R7 |
| T6 | Run full suite; visual check of isometric orientation; fix mapping if needed | T5 | test output | `fence_visual.tres` mapping only, if needed | R9, A1 |

## Task detail

### T1
- Done when: all 15 outline rows pass; OOB neighbor yields no bit; diagonal ignored.

### T2
- Done when: null mapping safe; `validate` flags missing tiles; icon uses mask 0.

### T3
- Done when: tool is idempotent; 16 tiles exist; existing authored art preserved.

### T4
- Done when: fence cells paint mapped tile; erase path unchanged; null `fence_visual` still returns early.

### T5
- Done when: each mask row asserts expected atlas coords; place/remove scenarios assert neighbor repaint.

### T6
- Done when: suite green; fence orientation matches art or mapping corrected.

## Context-efficiency rules

- T1 and T2 have no shared files. Run in separate contexts.
- T3 and T4 have no shared files. Run in separate contexts.
- T4 reads only the `render_fences` region and `fence_visual.gd`.
- Interfaces between tasks are fixed in `design.md`: mask bits N=1, E=2, S=4, W=8; helper names; 16-entry mapping.
- No task needs the full repo findings.
