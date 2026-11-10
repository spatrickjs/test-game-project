# Design — Hoe and Shovel Tools

## 1. Overview

Introduce a dedicated Hoe tool (`TOOL_HOE` / `DIG_GRASS`) for grass tilling and restrict the Shovel tool (`TOOL_REMOVE`) to crop and fence removal (`REMOVE_CROP` / `REMOVE_FENCE`). Both tools follow the standard queued action lifecycle: input creates a queued action and plot reservation; authoritative mutation occurs only upon farmer arrival after revalidation.

## 2. Architectural Placement

Adheres to `Presentation → Logic → Simulation → Data`:

| Layer | Responsibility |
|---|---|
| Presentation | Tool selection toggle (`INSPECT` switch), HUD state, highlight predicates, drag input mapping, visual refresh. |
| Logic | Enqueue/arrival validation, plot reservation, commit field mutations, report errors via `action_error`. |
| Data | Grid/cell state (`FieldCellState`), terrain (`GRASS`, `DRY_SOIL`), soil initialization copy, crop/fence occupancy. |
| Simulation | Unchanged (no tool input or queue responsibilities). |

Logic remains authoritative; presentation filters input only for interaction feedback and target highlighting.

## 3. Tool Modes and Action Mapping

| Active Mode | Target Condition | Action Kind | Direct Click Error Message |
|---|---|---|---|
| `TOOL_HOE` | In-bounds, empty `GRASS`, no crop, no fence | `DIG_GRASS` | `Hoe requires empty grass.` |
| `TOOL_REMOVE` | Crop tile | `REMOVE_CROP` | — |
| `TOOL_REMOVE` | Fence tile | `REMOVE_FENCE` | — |
| `TOOL_REMOVE` | Tile with neither crop nor fence | None | `Choose a crop to remove.` |
| `INSPECT` | Any tile | None | Standard inspect behavior |

* Selecting an active tool toggles back to `INSPECT` and clears highlights/drags.
* Enum values for `ToolMode` in `field_prototype_presenter.gd` must append `TOOL_HOE` to preserve serialization stability.

## 4. Lifecycle & Interaction Flow

1. **Selection:** UI press sets tool mode, updates HUD state/labels (`Tool: Hoe`, `Tool: Shovel`), and refreshes target highlights.
2. **Input / Selection:** Pointer converts to field coordinates.
   * **Direct Click:** Evaluates target eligibility. If invalid, logs action error message.
   * **Drag:** Evaluates eligibility independently per cell. Invalid or non-matching cells in path are skipped.
3. **Enqueue:** Logic validates bounds, target state, and plot reservation (`This plot already has a queued action.`). No tile mutation occurs at enqueue time.
4. **Arrival & Commit:** Upon farmer arrival, Logic revalidates preconditions.
   * *Stale target:* Action cancelled; reports stale action error without mutating field state.
   * *Valid target:*
     * `DIG_GRASS`: Terrain becomes `DRY_SOIL`; soil initialized via `initial_soil` copy; grass visual cleared.
     * `REMOVE_CROP`: Crop cleared; growth/vitality/disease stats reset; terrain and soil preserved.
     * `REMOVE_FENCE`: Fence cleared via existing removal path.
     * Release reservation and trigger presentation update.

## 5. Integration Key Points

* **HUD Setup:** Update `tools/bake_ui_to_scene.gd` and run `tools/setup_field_tools.gd` to bake the Hoe button into `field_prototype.tscn`.
* **Docs:** Update `docs/QUEUED_FIELD_ACTIONS.md` to reflect the Hoe/Shovel separation and per-tile independent drag processing.