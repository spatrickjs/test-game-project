# Design — Fence Auto-tiling

Traces to `requirements.md` (R1–R10).

## Approach

Derive connections from the snapshot at render time. Map mask to atlas tile. Existing full repaint on `cell_changed` handles neighbor updates (R3, R4).

## Layer changes

| Layer | Change |
|---|---|
| Data | None (R10). |
| Simulation | Add pure helpers to `FieldGridQueries`. |
| Logic | None. |
| Presentation | Neighbor-aware `render_fences`; extend `FenceVisual`; extend TileSet via tool. |

## Components

### Simulation — `FieldGridQueries`

- `fence_connections(grid, coords)` → connection mask (R1, R5, R6).
  - Reads four cardinal offsets only.
  - Null cell or no fence → bit unset.
- `fence_shape(mask)` → shape identifier (R2).
  - Shape enum is Simulation-local, not persisted, not a Data enum.
- Mask bit constants: N=1, E=2, S=4, W=8.
- No scene, Logic, or Presentation dependency.

### Presentation — `FenceVisual`

- Replace single tile with mask→(source_id, atlas_coords, alternative_tile) mapping.
- `validate(tile_set)` checks all 16 entries exist in the TileSet.
- `make_icon(tile_set)` uses mask 0 (R8).
- Keep null-safe behavior (R9).

### Presentation — `FieldWorldView.render_fences`

- For each fenced cell, compute mask via Simulation helper on the detached snapshot.
- Paint the tile mapped to the mask on `fence_layer`.
- Keep erase of cells that lost fences.
- Keep early exit when `fence_visual` is null.

### Tooling — `setup_fence_tool.gd`

- Extend, stay idempotent, preserve authored art.
- Create 16 atlas tiles in the standalone `fence_tile_set.tres`.
- Populate `fence_visual.tres` mapping.
- Pattern reference: `setup_crop_growth_visuals.gd`.
- Never hand-edit `.tres`/`.tscn`.

## Data flow

Snapshot → `render_grid` → `render_fences` → per cell: mask → mapped tile → `fence_layer`.

## Testing

| Test file | Covers |
|---|---|
| `tests/simulation/fence_connections_test.gd` (new) | R1, R2, R5, R6: all 15 outline rows, OOB, diagonal, non-fence. |
| `tests/presentation/fence_autotiling_test.gd` (new) | R3, R4, R7: atlas coords per mask; place/remove neighbor repaint. |
| `tests/presentation/fence_presentation_test.gd` (existing) | R9 regression. |

## Risks

- Isometric orientation (A1): grid-offset N may look wrong against art. Validate visually at the end; fix by remapping mask→tile only, no logic change.
- Inline TileSet serialization: keep standalone `.tres` loaded by `_ensure_fence_tile_set()`.
- Full repaint per change: acceptable at current grid sizes.

## Gate

Cross-layer change. Implementation starts after design approval.
