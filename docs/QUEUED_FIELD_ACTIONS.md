# Queued field tools and placeholder farmer

Implemented November 6, 2026 (Asia/Shanghai), following the user's explicit feature request.

## Player controls

- **Hoe** converts empty grass into dry soil. A drag locks to the first eligible cell's action; it never mixes actions across tile kinds.
- **Shovel** removes crops on occupied cells and destroys fences. A drag locks to the first eligible cell's action: removing crops or destroying fences. It never mixes these actions and no longer digs grass.
- **Water Bucket** converts empty dry soil into paddy mud. Grass must first be dug, and occupied plots cannot be converted. The existing **Water** button still adds soil moisture; it is a separate tool.
- **Move** reuses the existing button: select a source crop, then an empty compatible destination. Click the source again to cancel that selection. The farmer visits the source before the destination and commits the transfer at delivery.
- Planting, Hoe, Shovel, Bucket, Harvest, Water and Fertilize support mouse/single-finger drag selection. Move uses two single-plot selections.
- Pale green diamonds show eligibility. Cyan diamonds pulse during selection; amber diamonds pulse for queued plots and a pending Move source.
- Release queues actions in encounter order. A plot can be reserved by only one task at a time; transfers reserve both endpoints. Select a converted plot for its next operation after the current task finishes.
- Inspect mode keeps the existing left-mouse/single-finger camera pan. Middle mouse and two-finger camera gestures work with a tool selected. A second finger cancels an uncommitted selection before controlling the camera.
- Tool changes, Escape, focus loss and GUI interaction cancel uncommitted selection. Already queued work continues across tool changes. `FarmingController.cancel_actions()` provides explicit queue cancellation for future reset/UI callers.
- Next Turn is disabled while work is queued, and Logic also rejects turn advancement until the queue is empty.

## Layer boundaries and files

| Layer | File | Responsibility |
|---|---|---|
| Data | `src/data/enums/simulation_enums.gd` | New independent `FieldActionKind` enum; existing enum IDs unchanged |
| Data | `src/data/state/field_action.gd` | Copied task descriptions, logical coordinates, crop selection, soil additions, visit phase and revision stamps |
| Logic | `src/logic/farming/farming_controller.gd` | FIFO tasks, validation, reservations, stale-action rejection, terrain conversion and existing farming transactions |
| Presentation | `src/presentation/world/field_prototype_presenter.gd` | HUD intents, eligibility queries, queue/walker wiring and snapshot refresh |
| Presentation | `src/presentation/world/field_world_view.gd` | Viewport conversion, filtered drag selection, terrain/tuft refresh and beside-plot standing positions |
| Presentation | `src/presentation/world/field_selection_overlay.gd` | Procedural diamonds and time-based alpha pulse |
| Presentation | `src/presentation/world/farmer_agent.gd` | Procedural character, foot ellipse, visual locomotion and arrival signal |
| Editor tools | `tools/bake_ui_to_scene.gd`, `tools/setup_field_tools.gd` | Persistent Hoe and Water Bucket controls, actor, overlay, exported references and depth-sort wiring |

`FieldGridState` and `FieldCellState` remain passive data. Presentation receives detached snapshots and copied tasks, and never changes authoritative cells. No simulation formulas were changed. Existing immediate Logic APIs (`try_plant`, `remove_crop`, `transfer_crop`, `harvest_crop`, `apply_soil_additions`) remain usable by tests, fixtures and internal callers; player HUD actions now enqueue them.

## Queue and transaction contracts

`enqueue_action(request)` validates and copies the intent without mutating the field. `get_current_action()` returns a copy. `get_queued_coordinates()` includes both endpoints of a transfer. `action_error()` is the shared eligibility/enqueue/arrival validation path.

The presenter asks FarmerAgent to walk to the current stop. The actor reports `(action_id, coordinates)` on arrival; `arrive_at_action()` rejects outdated IDs and incorrect stops. It revalidates current rules and per-cell mutation revisions before committing. An invalid/stale task is removed, reports failure, clears its highlights and allows the next task to proceed. IDs remain monotonically increasing across resets so late arrivals cannot match new work.

Move has two stops. The source visit changes only the task's visit phase. The crop remains in the source cell until destination arrival, when the existing atomic `transfer_crop` transaction preserves its full crop payload and retains each plot's soil. Cancellation or failure after the source visit cannot lose a crop. The placeholder does not yet show a carried crop.

The Hoe's `DIG_GRASS` creates a distinct copy of `initial_soil`, changes only empty grass to dry soil, validates the candidate grid and commits once. Bucket conversion preserves existing soil values and changes empty dry soil to paddy mud. Bucket conversion does not itself add moisture; **Water** retains that operation. Queue actions do not advance growth or turn count. Harvest retains the quality receipt displayed by the HUD.

State changes refresh terrain, crops, the inspector and eligibility without reframing the camera or interrupting another drag. Grass decoration uses one seeded random sample per logical coordinate so conversion removes only the converted plot's tuft.

## Visual motion and configuration

`World/FarmerAgent` and `World/SelectionOverlay` are saved owned nodes with exported references. The actor uses `_draw()` only, with no sprite textures. `World` and crop/grass layers enable Y sorting; the actor shares the crop Z index and uses its feet as its sort origin. Terrain remains underneath. SelectionOverlay draws above the field.

Standing candidates are `center + 0.6 * (orthogonal_neighbor_center - center)` in Terrain-local space, converted to global space. The closest candidate to the farmer is chosen. This places the feet slightly beyond an isometric edge, rather than on the target center. Boundary plots allow an outside-grid standing offset. Default speed is 360 world pixels/second, exposed on FarmerAgent.

Motion is a straight-line presentation animation. Obstacle avoidance, navigation paths, collisions and a carried-crop sprite are not implemented. `_process()` is used only for walking and pulsing highlights; growth and environmental simulation remain discrete.

Selection diamonds use `Terrain.map_to_local()` and half of the TileSet's logical tile size, transformed into overlay space. Fast drags are sampled in terrain-local space to avoid skipping narrow diamonds at low camera zoom.

The saved scene was updated through Godot Editor node APIs and serialization. Scene UID, authored artwork, 20-FPS crop animation values, existing HUD layout and the user's cosmetic terrain border were preserved. Reload the scene in an already-open editor before playtesting.

## Verification

`tests/logic/queued_field_actions_test.gd` covers deferred mutation, conversion restrictions, reservations, detached tasks, stale/outdated arrival rejection, turn blocking, walking to non-center standing points, two-stop transfers, cancellation, both Shovel drag filters, mouse/touch selection, GUI/focus/mode cancellation, middle-mouse pan, two-finger gestures, saved scene wiring, highlights and tuft cleanup. Existing UI integration tests now advance the real walker before checking the original post-action assertions; they also check that clicking alone leaves state unchanged.

`tests/presentation/grass_overlay_test.gd` additionally verifies that conversion does not relocate other tufts. The runtime preview test checks every logical field tile instead of rejecting the existing cosmetic border.

Latest complete strict run: **16/17 pass**. Only `crop_growth_visuals_test.gd` fails with the twelve pre-existing **20-FPS saved / 8-FPS expected** mismatches. There were no engine errors or warnings in that run. Do not claim the entire suite is green. The new queue test also passed in a rendered OpenGL run; `.godot/queued_actions.png` was visually inspected. Physical mobile gesture testing remains outstanding.

```powershell
python tools/run_tests.py --godot 'C:\Program Files\Godot\Godot.exe.exe'
```

Editor tests require access to Godot's user settings directory. The runner contains seventeen tests. No commit or push was performed.
