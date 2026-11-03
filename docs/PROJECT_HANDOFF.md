# Project handoff: isometric crop disease education game

Last reviewed: **2026-11-04 (Asia/Shanghai)**. This document combines approved design decisions, files inspected in the workspace, and previously reported test results. Paths below are relative to the project root; `res://` means the directory containing `project.godot`.

## 1. Overview and continuation checkpoint

Undergraduate Computer Science thesis: a 2D isometric educational mobile game explaining how crop diseases spread and how field management can prevent or reduce them. The intended audience is the general public. Development follows incremental prompting and **game-first order**: playable terrain, planting, growth, and inspection precede epidemiological mathematics.

**Current checkpoint:** Phase 1 schemas/catalogs and Phase 2 Steps 2.1–2.2 are implemented. Step 2.3 inspector, presenter integration, and persistent UI baker are also implemented and tested. The immediate work is to bake/save and visually review the UI on the destination device, then approve the simulation design. Do not recreate Step 2.3 from scratch based on older plans describing it as unimplemented.

### Stack and entry points

- Godot 4, strictly typed GDScript 2.0, Resources, RefCounted state/models, signals, Node2D, TileMapLayer, Camera2D, and Control-based UI.
- Last tested engine: `4.7.2.stable.official.ed1daf0bf`; project declares Godot `4.7` and Mobile features. Use the same version initially to avoid migration differences.
- Mobile renderer; Windows rendering driver is configured as D3D12. Reassess renderer compatibility on another OS/device through the Editor.
- Project name: `Test Game Project`.
- Main scene: `res://field_prototype.tscn`; configured by UID in `project.godot`.
- Viewport: 1280 × 720; `canvas_items` stretch with expanding aspect.
- Previous workspace: `C:\Users\User\Documents\test-game-project`.
- Previous executable: `C:\Program Files\Godot\Godot.exe.exe` (machine-specific, not a project dependency).

## 2. Architecture and mandatory conventions

There are **four layers**, including the Simulation layer even though the current playable prototype primarily exercises Data, Logic, and Presentation.

| Layer | Location | Owns | Must not depend on |
|---|---|---|---|
| Data | `src/data/` | Definitions, catalogs, passive state, validation/copy helpers; future persistence schemas | Presentation or gameplay controllers |
| Simulation | `src/simulation/` | Pure RefCounted geometry and future discrete epidemic mathematics | Logic, UI, Node2D, TileSet |
| Game Logic | `src/logic/` | Field initialization, planting rules, growth, discrete turns; future actions and outcomes | Tile atlas coordinates or texture paths |
| Presentation | `src/presentation/` | Rendering, input intents, HUD, inspector, composition/presenter wiring | Direct mutation of authoritative simulation/game state |

Key rules:

1. **PCI protocol:** before implementing a new feature, propose touched layers, exact script/asset paths, formulas and edge cases, then wait for explicit approval. Existing authorized fixes can proceed. This handoff does not approve new simulation formulas.
2. Use explicit types for variables, properties, parameters, return values, collections, and enum selectors. Put `class_name` before `extends` consistently with this project.
3. Execute environmental, growth, and epidemic updates on discrete turns/ticks. Never run simulation calculations in `_process()`.
4. Inject scenes, textures, resources, and node references through `@export`. Editor scaffolding may reference the script it installs; gameplay scripts must not hardcode asset loads.
5. Never generate or hand-patch raw `.tscn` or `.tres` text. Use the Godot Editor, EditorScript node APIs, ownership, and Godot serialization. The concern is malformed serialized references/UIDs; `.tscn` itself is a text format, not a binary file.
6. Shared enum identifiers belong in `SimulationEnums`; preserve numeric values for future save compatibility. Avoid circular dependencies and built-in identifier collisions. A prior enum parse error caused a cascade across dependent resources; the user confirmed the fix compiled cleanly. The exact original offending token is not recorded here.
7. Validation returns `PackedStringArray` and reports invalid/non-finite values without silently clamping or mutating data. Empty rule arrays are neutral. Partial catalogs are allowed during authoring; null entries and duplicates are errors.
8. Scene creation is editor-time for persistent UI, while **field tile generation is intentionally runtime**. `FieldWorldView` paints a logical grid into `TileMapLayer`; do not manually maintain 54 tile nodes or bake the dynamic field as UI.

### Rules versus artwork

`TerrainData` and `TerrainDatabase` define plantability and allowed crops. `CropData` and `CropDatabase` define crop identity, growth, immunity, and tolerance requirements. `TerrainTileVisualMap` is exclusively a Presentation mapping from terrain identity to TileSet source ID, atlas coordinates, and alternative tile.

Changing terrain artwork must never change planting or disease behavior. Changing allowed crops is a data-authoring operation on `TerrainData.allowed_crops`, not an atlas-coordinate conditional in gameplay code.

## 3. Code inventory

### Data scripts (completed)

All paths in this table are under `src/data/`.

| Script | class_name | Key API / responsibility |
|---|---|---|
| `enums/simulation_enums.gd` | SimulationEnums | Shared crop, disease, terrain, compartment, algorithm, nutrient, abiotic, and neighborhood enums |
| `resources/soil_state.gd` | SoilState | Macro/micro and unified `get_nutrient()` / `set_nutrient()` accessors; `validate()`, `copy()` |
| `resources/abiotic_state.gd` | AbioticState | Field-wide environment; `validate()`, `copy()` |
| `resources/float_range.gd` | FloatRange | Inclusive min/max interval; `validate()`, `copy()` |
| `resources/nutrient_rule.gd` | NutrientRule | Nutrient selector, optimal range, weight; `validate()`, `copy()` |
| `resources/abiotic_rule.gd` | AbioticRule | Factor selector, optimal range, weight; `validate()`, `copy()` |
| `resources/crop_data.gd` | CropData | Identity, growth ticks, base immunity, optional tolerance/requirement arrays; `validate()`, `copy()` |
| `resources/disease_data.gd` | DiseaseData | Rates, default algorithm, target crop, neighborhood, trigger arrays; `validate()`, `copy()` |
| `resources/terrain_data.gd` | TerrainData | `is_plantable`, `allowed_crops`; `validate()`, `copy()` |
| `databases/crop_database.gd` | CropDatabase | `get_crop()`, `has_crop()`, `validate()` |
| `databases/disease_database.gd` | DiseaseDatabase | `get_disease()`, `get_diseases_for_crop()`, `validate()` |
| `databases/terrain_database.gd` | TerrainDatabase | `get_terrain()`, `has_terrain()`, `validate()` |
| `state/field_cell_state.gd` | FieldCellState | Passive per-cell state; `is_mature(crop_data)`, `validate()`, `copy()` |
| `state/field_grid_state.gd` | FieldGridState | Row-major cell container, shared environment; `initialize()`, `is_in_bounds()`, `get_cell()`, `set_cell()`, `validate()`, `copy()` |

Authored resources present: crop and terrain catalogs; sugarcane, rice, corn, dry-soil, paddy-mud, and grass definitions. No authored DiseaseDatabase `.tres` or nine calibrated disease definitions were found during this review. A completed schema is not empirical calibration. SaveData and benchmark-result schemas are not implemented.

### Logic, Simulation, and Presentation

| Script | Class / key API |
|---|---|
| `src/simulation/grid/grid_neighborhood.gd` | GridNeighborhood: static `get_neighbor_coordinates()`, `get_distance_in_tiles()` |
| `src/logic/grid/field_grid_queries.gd` | FieldGridQueries: static `can_plant()`, `validate_terrain_assignments()` |
| `src/logic/farming/farming_controller.gd` | FarmingController: `initialize_field()`, `try_plant()`, `advance_growth()`, `get_grid_snapshot()`, `is_initialized()` |
| `src/logic/turns/turn_controller.gd` | TurnController: `advance_turn()`, `reset_clock()` |
| `src/presentation/world/terrain_tile_visual.gd` | TerrainTileVisual: terrain/source/atlas/alternative mapping entry |
| `src/presentation/world/terrain_tile_visual_map.gd` | TerrainTileVisualMap: `get_visual()`, `validate(tile_set)` |
| `src/presentation/world/field_world_view.gd` | FieldWorldView: `render_field()`, `render_grid()`, `refresh_crops()`, `frame_field()`, coordinate conversion, `_unhandled_input()` |
| `src/presentation/world/crop_debug_overlay.gd` | CropDebugOverlay: `show_snapshot()`, `get_cell_draw_position()`, `_draw()` |
| `src/presentation/world/field_prototype_presenter.gd` | FieldPrototypePresenter: composition root; connects UI intents to Logic and refreshes views |
| `src/presentation/ui/inspectors/tile_inspector_view.gd` | TileInspectorView: `display_cell()`, `clear_display()`, `validate_configuration()`, `close_requested` |
| `tools/bake_ui_to_scene.gd` | EditorScript: complete persistent HUD and inspector baker |
| `src/presentation/ui/inspectors/build_tile_inspector_scene.gd` | Compatibility entry point inheriting the complete baker |

## 4. Approved domain and simulation contracts

### Crops and diseases

| Crop | DiseaseId members |
|---|---|
| Sugarcane | `RSSI`, `SUGARCANE_SMUT`, `LEAF_SCALD` |
| Rice | `RICE_TUNGRO`, `BACTERIAL_LEAF_BLIGHT`, `RICE_BLAST` |
| Corn | `COMMON_CORN_RUST`, `PHILIPPINE_DOWNY_MILDEW`, `EAR_ROT` |

Preserve `RSSI` as the approved project identifier for ratoon stunting; do not silently rename existing IDs.

### Environmental units and rule semantics

- Nutrients: N, P, K, B, Cl, Cu, Fe, Mn, Mo, Ni, Zn, each normalized 0–1 with default 0.5. These are prototype availability values, not measured agronomic concentrations.
- Unified `NutrientType`: macro nutrients first, then micro nutrients, IDs 0–10. Macro and Micro selectors also remain available.
- Soil pH: 0–14, default 7.0; soil is per tile.
- Light intensity and relative humidity: normalized 0–1, defaults 0.5.
- Atmospheric pressure: kPa, default 101.325; Inspector range 80–110 with `or_greater` / `or_less`. Treat authoring hints separately from validation.
- AbioticState is field-wide for the initial prototype.
- Crop nutrient requirements and disease nutrient susceptibility rules use a **healthy/resistant inclusive interval**. Values outside it can incur penalties, allowing deficiency and excess effects.
- Disease abiotic trigger intervals are **disease-favorable**: inside the interval increases pressure relative to a neutral baseline.
- Empty/unconfigured rules cause no penalty. Exact penalty curves, combination formulas, and calibration remain future approved work.

### Algorithm comparison (SOP 2)

The same DiseaseData must support `SPATIAL_SIR = 0`, `SPATIAL_SEIR = 1`, and `STOCHASTIC_CA_SIR = 2`. A future benchmark runner may override `default_algorithm` without mutating the resource. This replaces the earlier SIRVariant selector; waning immunity remains a rate parameter.

- `beta`, `sigma`, `gamma`, and `xi` are nonnegative rates per simulation time unit, initially one unit per tick. They are not probabilities and may exceed 1.
- `mortality_probability` is a 0–1 conditional chance that removal produces death.
- `RemovedOutcome`: NONE=0, RECOVERED_IMMUNE=1, DEAD=2. With xi=0, recovered immunity persists; xi>0 permits waning. Dead never returns to susceptible.
- Continuous spatial models treat a tile as a local crop stand: S, E, I, recovered-immune, and dead fractions are authoritative and sum to 1 for an occupied tile. SIR does not use an exposed stage.
- CA uses categorical SIRState and RemovedOutcome as authoritative, with one-hot fractions. Do not infer categories by arbitrarily thresholding continuous fractions.
- Empty cells have zero fractions. `has_crop` and `has_active_disease` determine whether their associated enum IDs are meaningful.
- One active disease per cell. Co-infection is out of scope.
- Von Neumann uses Manhattan distance within the radius; Moore uses Chebyshev distance. Exclude the center and clip to bounds.
- Approved future kernel: `exp(-distance_decay * euclidean_distance_in_tiles)` inside the chosen neighborhood. Geometry is implemented; transmission mathematics is not.
- Grass is not a crop host but does not block dispersal geometry.

## 5. Playable prototype behavior and scene wiring

Initial field: 9 × 6, three configurable uniform terrain bands. Intended permissions: dry soil supports sugarcane/corn; paddy mud supports rice; grass is unplantable and has null soil. Plantable cells require independent valid SoilState instances. Inspect the scene's exported `terrain_bands` for visual order rather than assuming enum order.

Planting is free on eligible empty cells. Next Turn advances discrete growth, capped at CropData.growth_ticks. Maturity is derived with `is_mature(crop_data)`. Harvesting, treatments, win/loss, and epidemic progression are not implemented.

```text
FieldPrototype (Node; FieldPrototypePresenter)
├── FarmingController (Node)
├── TurnController (Node)
├── World (Node2D; FieldWorldView)
│   ├── Terrain (TileMapLayer)
│   ├── CropOverlay (Node2D; CropDebugOverlay)
│   └── Camera2D
└── HUD (CanvasLayer)
    ├── Panel (PanelContainer)
    │   └── Margin / Controls
    │       ├── TurnLabel, SelectedCropLabel, StatusLabel
    │       ├── CropButtons / SugarcaneButton, RiceButton, CornButton
    │       └── NextTurnButton
    └── TileInspectorPanel (PanelContainer; TileInspectorView)
        └── Margin / Layout
            ├── Header / TitleLabel, CloseButton
            └── Scroll / Content
                ├── Terrain, soil, crop, growth, disease and state labels
                ├── GrowthBar
                └── Compartments (GridContainer): five label/bar pairs
```

Input and update flow:

1. World converts mouse/touch viewport coordinates through the TileMapLayer transform and `local_to_map()`, then emits `cell_clicked(Vector2i)`.
2. Presenter starts in Inspect mode with no crop button selected. Selecting a crop enters Plant mode and closes the inspector. Clicking that selected crop again returns to Inspect mode.
3. Plant clicks call FarmingController.try_plant(). Inspect clicks retrieve a fresh detached grid snapshot and selected cell.
4. Farming signals `field_initialized`, `cell_changed(coordinates)`, or `planting_rejected(coordinates, reason)`; TurnController emits `turn_completed(turn_index)`.
5. Presenter refreshes crop visuals and an open inspector after relevant changes. Closing the inspector clears selection, preventing later turns from reopening it. Signal connections are guarded against duplicates.

`TileInspectorView.display_cell(cell_state: FieldCellState, crop_data: CropData)` accepts a **cell**, not FieldGridState. It displays terrain, pH/NPK, crop growth/maturity, optional active disease name, categorical state, removal outcome, and all five fraction percentages. Invalid values are flagged. DiseaseDatabase is optional; unresolved active IDs are shown explicitly. There is no separate crop-health scalar yet.

Overlay positioning uses TileMapLayer.map_to_local() with transforms into overlay space. Snapshot refresh queues redraw; valid fonts/fallback handling and mature-color markers are implemented.

## 6. Tile assets and known atlas discrepancy

Temporary textures are under `assets/art/tilesets/terrain/`. Actual filenames currently have double extensions: `dry_soil.png.png`, `paddy_mud.png.png`, `grass.png.png`.

Current prototype settings: original images 3500 × 3500, import size limit 512, atlas texture region 512 × 512, isometric TileSet.tile_size `(276, 140)`, texture_origin `(4, -14)`. Re-measure if images, crop/padding, or import settings change; these are not universal dimensions.

| Terrain | Source ID in current visual map | Atlas coords | Alternative |
|---|---|---|---|
| DRY_SOIL | 0 | (0, 0) | 0 |
| GRASS | 1 | (0, 0) | 0 |
| PADDY_MUD | 2 | (0, 0) | 0 |

Each image is a separate atlas source. Never use `(0,1)` or `(0,2)` as terrain selectors. Source IDs are presentation-only and may change when reauthoring assets.

**Status distinction:** the user reported atlas slicing/mapping resolved and playable clicking/planting/turns working. However, the on-disk `field_prototype.tscn` still contains stale `(0,1)` and `(0,2)` atlas definitions as of this review, and prior headless scene loads emitted related errors. Mapping code is correct; saved TileSet cleanup still needs verification in the Editor. Remove invalid entries using the TileSet editor and save; do not repair by raw scene-text edits.

## 7. Step 2.3 persistent UI: current workflow

The latest refactor removed runtime layout/style overrides from presenter and inspector. Their `_ready()` methods use exported existing controls; no runtime UI creation is required. The earlier problem also included an inspector saved as hidden and runtime repositioning, not solely missing ownership.

1. Stop playtesting and open `field_prototype.tscn` as the active edited scene.
2. Open `res://tools/bake_ui_to_scene.gd` in the Script Editor; do not attach it to a node.
3. Run File > Run / Ctrl+Shift+X.
4. The baker creates missing expected HUD/inspector controls, assigns `owner = scene_root`, and wires presenter and inspector UI exports.
5. Press Ctrl+S to serialize through Godot. The baker intentionally does not auto-save.
6. Edit positions, anchors, offsets, themes, sizes, and wrapping in the Editor. Container children use size flags/container layout rather than free positioning.

The baker supports Undo/Redo and reruns without duplicate nodes. It preserves existing positions, themes, nonempty captions, optional disease catalog, and Logic/World bindings. It rejects incompatible/nested nodes instead of replacing them. Inspector visibility is enabled for authoring; runtime hides it until inspection. Existing HUD sizing is preserved, so resize the current large panel manually. There is no longer an automatic runtime shrink-to-fit. Configure responsive anchors deliberately and keep bars on a 0–100 percentage range.

Reference: `docs/BAKE_UI_SETUP.md` is authoritative for the latest UI workflow. Older `STEP_2_3_SETUP.md` responsive-layout notes describe the prior prototype. `docs/STEP_2_2_SETUP.md` retains world/TileSet setup context.

## 8. Verification and new-device startup

Previously observed results after the UI refactor:

- `tests/presentation/tile_inspector_builder_editor_test.gd`: **TILE_INSPECTOR_BUILDER_EDITOR_PASS**, exit 0. Checks bindings/ownership, Undo/Redo, rerun, missing HUD reconstruction, and in-memory PackedScene round trips. Does not save the user scene.
- `tests/logic/field_scene_integration.gd`: **FIELD_SCENE_INTEGRATION_PASS**, exit 0. Covers inspection, planting, turns, closing, updates, input, and preserving authored UI positions.
- `tests/logic/field_prototype_smoke.gd` also exists for core prototype checks; no new result is claimed in this documentation task.
- Headless editor runs also emitted pre-existing atlas errors and environment/editor-directory or shutdown resource warnings. A test PASS does not mean every project log is clean. Tests were not rerun merely to write this document.

Portable command templates (replace `godot` with the installed executable):

```sh
godot --headless --path . --editor --quit --log-file res://.godot/import-check.log
godot --headless --path . --script res://tests/logic/field_prototype_smoke.gd --log-file res://.godot/smoke.log
godot --headless --path . --script res://tests/logic/field_scene_integration.gd --log-file res://.godot/integration.log
godot --headless --path . --editor --script res://tests/presentation/tile_inspector_builder_editor_test.gd --log-file res://.godot/builder.log
```

On Windows use the console executable or a process runner that waits for exit. Ensure `.godot` exists and log paths are writable. An absolute workspace log path is an alternative if `res://` logging fails. A log-file write error alone is not a GDScript parse error.

Transfer checklist:

- Copy the full project, including project.godot, source, `.gd.uid` sidecars, authored scenes/resources, original assets, import settings, tools, tests, and docs.
- Preserve relative paths and filename case. `.godot` is normally regenerated, but the current scene contains direct imported `.ctex` paths: verify those resolve after importing the original images. Prefer reassigning source textures in the Editor if regeneration leaves broken references.
- Open/import the project and let script class registration finish before playtesting.
- Open the prototype, verify catalogs/visual mappings, clean stale atlas entries, run the UI baker if needed, save, and play with F6.
- Confirm dry-soil and rice permissions, grass rejection, maturity cap, Inspect/Plant toggling, inspector refresh, and close behavior.
- No Git repository was detected during the preceding implementation session. Do not assume changes were committed or a remote backup exists.

## 9. Immediate next steps and remaining scope

### Finish the Step 2.3 checkpoint

1. Verify the persistent baked UI on the new device; style and position the HUD/inspector in the Editor.
2. Confirm the saved TileSet is free of stale atlas entries.
3. Assign a DiseaseDatabase when authored; absence is currently supported.
4. Obtain the user's clean playtest/compile confirmation before starting the next implementation phase.

### Phases 3 and 4: proposed upcoming work, not yet implemented

Phase numbering shifted in earlier prompts. Preserve the agreed sequence and confirm the next step title before implementation: simulation design, pure algorithms and metrics, then game/benchmark integration.

- Propose exact tick/time-step semantics, nutrient/abiotic penalty formulas and aggregation, immunity effects, exposure/incubation/removal/waning handling, and bounded numerical updates.
- Implement interchangeable Spatial SIR, Spatial SEIR, and stochastic CA-SIR against the same data contracts. Keep Simulation independent of Logic and UI.
- Decide synchronous update/double-buffer policy, seeded random reproducibility, compartment conservation, and algorithm-specific validation before coding.
- Integrate one simulation tick through Logic/TurnController, then refresh snapshots/inspector. Avoid coupling numerical work to rendering.
- Design fair mobile benchmarks: shared starting conditions, disease parameters, grid sizes, time horizon, repeated seeded runs, timings/memory, and explicit rendering overhead policy. None of these benchmark measurements are available yet.
- Define soil/disease metrics and research data provenance; normalized placeholders are not validated agronomic constants.
- Design SaveData, benchmark schemas/catalog completeness checks, treatment actions, harvesting, and outcomes in separately approved increments.

## 10. Coding, assets, and change discipline

Use snake_case files/methods/properties, PascalCase class names, UPPER_SNAKE_CASE enum members/constants, explicit return types, small components, and descriptive signals. Keep validation diagnostics index-prefixed for catalog entries. Treat shared definition Resources as read-only at runtime and use copies for mutable per-tile state/snapshots.

Reserved/planned locations: `src/logic/autoloads/` for a future typed signal bus if needed; `assets/art/models_3d/blender_source/` for possible Blender sources or prerendered meshes. These are approved organizational destinations, not implemented 3D gameplay or singleton systems. Current temporary art lives under `assets/art/tilesets/terrain/`.

Adopt conventional commits when version control is initialized: `feat(ui): bake persistent inspector controls`, `fix(world): validate atlas source coordinates`, `refactor(simulation): separate neighborhood geometry`, `test(logic): cover terrain planting rules`, `docs: update project handoff`. Use `type(scope): concise imperative description`, document behavior and relevant verification, and avoid claiming unrun tests or calibrated research results.

For the next assistant: read this handoff and current scripts first, follow PCI for new work, keep the four-layer boundary, and continue from the existing inspector implementation rather than replacing it with a second runtime UI system.
