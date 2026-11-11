# Repo Findings — Fence Auto-tiling

Investigation of the existing codebase to ground the design of the Fence Auto-tiling
feature defined in [`fence-autotiling.feature`](fence-autotiling.feature). Scope: what
already exists, what enables the feature, what's missing, layering constraints, and open
decisions. This document is context for the upcoming `requirements.md` / `design.md` /
`tasks.md`.

## Feature summary (from fence-autotiling.feature)

- Fences connect to **cardinal** neighbors (N/E/S/W) that also have a fence.
- A fence's **connections** = the set of cardinal sides with an adjacent fence.
- A fence's **shape** is derived from connections:
  - none → `post`; one → `end`; two opposite → `straight`; two adjacent → `corner`;
    three → `T`; four → `cross`.
- Placing/removing a fence updates the connections of its neighbors.
- Non-fence tiles (feature calls them "stone blocks") and diagonal fences do **not** connect.

## Current fence system

| Concern | File | Current state |
|---|---|---|
| Data state | `src/data/state/field_cell_state.gd` | `has_fence: bool`. `validate()` enforces fenced ⇒ GRASS + no soil. No connections/shape field. |
| Fence action | `src/logic/farming/farming_controller.gd` | `FENCE` (kind 8) / `REMOVE_FENCE` (9) actions set/clear `has_fence`. `action_error()` rejects fencing an already-fenced tile, a queued tile, or an out-of-field tile. |
| Render hook | `src/presentation/world/field_world_view.gd` → `render_fences(snapshot)` | Erases cells that lost their fence; paints **one fixed atlas tile** (`fence_visual.source_id`/`atlas_coords`/`alternative_tile`) on every `has_fence` cell. Called from `render_grid()` (l.159, the function invoked by `_on_cell_changed`) and the crop-refresh path (l.191). |
| Visual resource | `src/presentation/world/fence_visual.gd` (`FenceVisual`, `@tool` Resource) | Holds a single `(source_id, atlas_coords, alternative_tile)`. `validate(tile_set)`, `make_icon(tile_set)`. Comment: "Logic and Data never see it." |
| TileSet | `src/presentation/world/fence_tile_set.tres` (standalone) | Single source (id 0), one tile at `(0,0)`. Loaded at runtime via `_ensure_fence_tile_set()` (inline `TileSetAtlasSource` does not serialize — limitation noted at `field_world_view.gd:26-27`). |
| Scene wiring | `tools/setup_fence_tool.gd` (EditorScript) | Creates `FenceLayer`, the standalone TileSet source + one tile, and `fence_visual.tres`; assigns `fence_layer`/`fence_visual` on `FieldWorldView`. Idempotent; preserves authored art/transforms. |
| HUD | `src/presentation/world/field_prototype_presenter.gd` | `fence_button.icon = world_view.get_fence_icon()` (from `make_icon`). |
| Tests | `tests/presentation/fence_presentation_test.gd`, `tests/logic/fence_treatment_test.gd`, `tests/logic/fence_treatment_property_test.gd`, `tests/simulation/fence_containment_test.gd` | Presentation test reads `fence_layer`; asserts mode/eligibility and null-safety (`fence_visual == null`). |

## Findings

### What already enables the feature (minimal work)
1. **Neighbor updates are automatic.** `render_fences` repaints *every* fence cell from the
   snapshot on each `cell_changed` (`_on_cell_changed` → `render_grid` → `render_fences`).
   The feature's "placing/removing a fence updates neighbors" needs **no new update
   propagation** — once the per-cell paint is neighbor-aware, a changed snapshot repaints
   all affected fences.
2. **Connections are derivable, not stateful.** A fence's connections are exactly which
   cardinal neighbors have `has_fence`. That is a pure function of the grid, readable from
   the same detached snapshot `render_fences` already iterates. So no new Data field is
   strictly required (avoids save-stability/migration per the tech rule on enums).
3. **Out-of-bounds / non-fence neighbors are already handled.** `snapshot.get_cell(offset)`
   returns `null` outside the grid; the existing render loop already null-guards
   (`field_world_view.gd:298`). `null` or `not has_fence` ⇒ no connection, satisfying
   "non-fence blocks do not connect" and "diagonal fences do not connect" (diagonals are
   simply not among the 4 cardinal offsets).
4. **Cardinal-neighbor convention exists.** `standing_point()` uses
   `Vector2i.LEFT/RIGHT/UP/DOWN` as the four orthogonal neighbors. A natural mapping is
   N=`(0,-1)`, E=`(1,0)`, S=`(0,1)`, W=`(-1,0)`.

### What's missing / must be built
1. **No autotiling precedent.** Grep for `set_cells_terrain_connect` / `terrain_peering` /
   Godot autotile found nothing. Terrain renders via an explicit per-type visual map
   (`terrain_tile_visual_map.gd` → `TerrainTileVisual`, painted at
   `field_world_view.gd:152-156`). So the project convention is "explicit per-tile visual
   map," **not** Godot's TileSet-terrain autotile. The fence autotiler must be custom
   GDScript: `connections → shape → atlas_coords`.
2. **Single-tile atlas is insufficient.** `fence_tile_set.tres` has one tile; `FenceVisual`
   points at one tile. Autotiling needs atlas tiles for `post`, `end` (×4 or ×1+rotation),
   `straight` (×2), `corner` (×4), `T` (×4), `cross` (×1) — up to ~16 tiles, or fewer using
   rotation/alternatives.
3. **`FenceVisual` must gain a shape→atlas mapping** (e.g., a `Dictionary` keyed by shape,
   or per-connection atlas coords), with `validate()` checking every referenced tile, and
   `make_icon()` using the `post` tile.
4. **Atlas authoring must be a tool script** (tech rule: never hand-edit `.tres`/`.tscn`).
   Extend `setup_fence_tool.gd` or add `setup_fence_autotiling.gd` to create the additional
   atlas tiles; precedent: `tools/setup_crop_growth_visuals.gd` builds multi-tile atlases via
   `TileSetAtlasSource.create_tile`.
5. **Shape/connection derivation needs a home.** Pure function of connections. Could live in
   Presentation (only used to pick art) — simplest. If the feature's `connections`/`shape`
   must be asserted by non-presentation tests, a pure helper in Simulation
   (`FieldGridQueries.fence_connections(grid, coords) -> int`) is clean and scene-free,
   matching the "Simulation has no scene/Logic/Presentation deps" rule.

### Layering analysis (Presentation → Logic → Simulation → Data)
- **Data**: no change required if connections/shape are derived. (Optional: a save-stable
  `FenceShape` enum only if shape must be persisted — not recommended; derive instead.)
- **Simulation**: optional pure `fence_connections(grid, coords)` helper for testability.
  No rendering IDs (respects the Data-no-rendering-IDs rule).
- **Logic**: likely **no change**. `FENCE`/`REMOVE_FENCE` already set/clear `has_fence`; the
  snapshot flows to `render_fences`.
- **Presentation**: the real work — neighbor-aware paint in `render_fences`, extended
  `FenceVisual`, extended TileSet via tool. Reads only from the detached snapshot (respects
  the "others get detached `copy()` snapshots" rule).

## Open questions / decisions
1. **N/E/S/W meaning in isometric space.** The grid is isometric. Is "N" the grid offset
   `(0,-1)` (matches `standing_point`'s UP) or the visually-upward isometric direction? The
   simplest, code-consistent choice is grid offsets; confirm against intended art
   orientation.
2. **Connection source of truth.** Derive at render time (recommended, zero Data change)
   vs. store a 4-bit connection field on `FieldCellState` (simpler to assert, but needs
   save-stable migration and a write site on fence place/remove).
3. **Shape home.** Presentation-only (recommended) vs. Data enum. If Presentation-only, the
   `.feature` "shape" assertions are checked via atlas coords (precedent:
   `crop_growth_visuals_test` reads atlas). If a cross-layer contract is wanted, add a
   Simulation helper + optional Data enum.
4. **Atlas layout.** One tile per (shape, orientation) (~16 tiles) vs. fewer tiles + Godot
   alternative/rotation. Affects the `FenceVisual` mapping shape and the tool script.
5. **"Stone block" / non-fence blocker.** No block concept exists in Data. The feature uses
   "stone block" as a stand-in for any non-fence tile. Confirm autotiling only needs
   `neighbor.has_fence` (yes, per scenarios) — no new block type required.

## Risks
- **Isometric orientation mismatch** (Q1) could make shapes visually wrong even if logic is
  right — needs an art/offset decision before implementation.
- **Inline TileSet serialization limitation** (`field_world_view.gd:26-27`): the fence
  TileSet must remain a standalone `.tres`; the autotile atlas tiles belong there, loaded via
  `_ensure_fence_tile_set()`.
- **`render_fences` performance** already does a full O(W×H) repaint each `cell_changed`;
  autotiling adds per-cell neighbor reads (4 lookups) — fine at current grid sizes, but it
  does not become incremental.
- **Save/round-trip** if connections are stored: must follow "Enum numeric values are
  save-stable; never reorder, only append." Derivation avoids this entirely.

## Files likely touched
- `src/presentation/world/field_world_view.gd` — `render_fences` neighbor-aware paint
  (primary change).
- `src/presentation/world/fence_visual.gd` — add shape→atlas mapping; extend `validate()`
  and `make_icon()`.
- `src/presentation/world/fence_tile_set.tres` — add atlas tiles (via tool, not hand-edit).
- `tools/setup_fence_tool.gd` (or new `tools/setup_fence_autotiling.gd`) — author the
  autotile atlas.
- (Optional) `src/simulation/...` — pure `fence_connections` helper.
- Tests: new `tests/presentation/fence_autotiling_test.gd` (template:
  `fence_presentation_test.gd`); optional `tests/simulation/...` for the helper.

## Test plan (mirrors feature scenarios)
- Per neighbor-combination row in the Examples table: set fences on the listed sides of
  (5,5), render, assert `fence_layer` atlas coords for (5,5) equal the chosen tile for the
  expected shape.
- Place/remove scenarios: assert neighbor fences' atlas coords update after a fence is
  added/removed (no new propagation code needed; just drive enqueue+arrive or a direct
  snapshot render).
- Non-fence / diagonal scenarios: place a non-fence (or a fence on a diagonal) and assert
  (5,5) connections = none / no diagonal connection.
- Null-safety regression: `render_fences` with `fence_visual == null` (already covered by
  `fence_presentation_test.gd:158-161`) must still pass after the extension.

## Spec status
`.kiro/specs/fence-autotiling/` currently contains only `fence-autotiling.feature`. The
sibling `fence-tool/` spec has the full set (`requirements.md`, `design.md`,
`fence_treatment.feature`, `tasks.md`). To follow project convention and the
`game-acceptance-criteria` steering (implementation follows Gherkin), the next steps after
these findings are: `requirements.md` → `design.md` → `tasks.md`, with implementation gated
on design approval (cross-layer change per `workflow` rule #5).
