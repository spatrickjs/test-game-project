# Requirements — Fence Auto-tiling

Source: `fence-autotiling.feature`, `repo-findings.md`.

## Glossary

- **Cardinal sides**: N=(0,-1), E=(1,0), S=(0,1), W=(-1,0) in grid offsets.
- **Connections**: set of cardinal sides whose neighbor tile has a fence.
- **Shape**: classification of connections (post, end, straight, corner, T, cross).
- **Connection mask**: 4-bit value, N=1, E=2, S=4, W=8.

## Assumptions (resolve open questions)

- A1: N/E/S/W are grid offsets, not screen directions.
- A2: Connections and shape are derived, never stored.
- A3: Shape classification lives in Simulation (pure, scene-free).
- A4: Atlas has one tile per connection mask (16 tiles). No rotation or alternatives.
- A5: "Stone block" means any tile without a fence.

## Requirements

| ID | Requirement | Scenarios |
|---|---|---|
| R1 | A fence's connections SHALL be the cardinal sides whose neighbor has a fence. | Shape outline |
| R2 | Shape SHALL be: none→post; one→end; two opposite→straight; two adjacent→corner; three→T; four→cross. | Shape outline |
| R3 | Placing a fence SHALL update connections of its fenced cardinal neighbors. | Placing updates neighbors |
| R4 | Removing a fence SHALL update connections of its fenced cardinal neighbors. | Removing updates neighbors |
| R5 | A neighbor without a fence, or outside the grid, SHALL NOT count as a connection. | Non-fence blocks |
| R6 | Diagonal fences SHALL NOT count as connections. | Diagonal fences |
| R7 | Each fence cell SHALL render the atlas tile mapped to its connection mask. | All |
| R8 | The fence HUD icon SHALL use the tile for mask 0 (post). | — |
| R9 | Rendering SHALL NOT fail when `fence_visual` is null. | Regression |
| R10 | No change to `FieldCellState`, save format, or Logic actions. | — |

## Non-goals

- Persisting connections or shape.
- Incremental repaint.
- Isometric screen-direction mapping.
- New block types.
