# Project handoff: isometric crop disease education game

Last reviewed: **2026-11-06 (Asia/Shanghai)**. This document combines approved design decisions, files inspected in the workspace, and previously reported test results. Paths below are relative to the project root; `res://` means the directory containing `project.godot`.

## 1. Overview and continuation checkpoint

Undergraduate Computer Science thesis: a 2D isometric educational mobile game explaining how crop diseases spread and how field management can prevent or reduce them. The intended audience is the general public. Development follows incremental prompting and **game-first order**.

**Current checkpoint: 9×9 manual-world authoring, queued farming and presentation improvements implemented.** The saved playable field starts entirely as grass. Shovel retains crop removal and adds empty-grass digging; Water Bucket converts empty dry soil to paddy mud; Move reuses the existing control. Player actions wait for the procedural farmer to walk beside plots. Drag selection, eligibility diamonds, blinking queued plots, two-stop transfers, crop shadows and geometric camera framing are implemented. Automatic background grass is disabled and its unused scene node removed. The playable 9×9 editor preview remains enabled. Current authored surroundings are `BackgroundTerrain`, `Foliage` and `Trees`; preserve their painted cells and Inspector settings.

**Verification status: no current full-suite certification.** The last complete strict run was **16/17 passing at the earlier queue checkpoint**, with twelve saved-20-FPS versus expected-8-FPS crop-animation mismatches. The runner now contains **18 tests**. Later targeted background, camera and editor/runtime preview checks passed during implementation, but the current scene has subsequent user edits (painted surroundings, renamed decoration layers, camera offset and artwork changes). No tests were rerun for this documentation-only refresh. All-grass initialization also invalidates older tests that assume initially plantable dry/paddy bands; the later crop-visual run exhibited those fixture failures in addition to speed mismatches. See section 8 before claiming a clean suite.

**Resume here:** the user intends to create replacement isometric assets and change tile dimensions. Autotiling and the proposed 128×64 footprint have only been discussed, not implemented or selected as final specifications. Obtain the actual assets/dimensions before migrating; preserve the current 9×9 logical field, manual scenery, animation resources and Inspector edits. Read section 19 for the proposed sheet layout and limitations. Reconcile animation speed and authoring-dependent test fixtures before a fresh full-suite claim. Physical mobile/safe-area checks and obstacle-aware walking remain outstanding. This turn updates documentation only; no scene regeneration, code changes, commit or push is authorized by the handoff refresh itself.

Detailed continuation guides:

- [EDITABLE_BACKGROUNDS.md](EDITABLE_BACKGROUNDS.md): manual background workflow and 9×9 placement guide. Its original `BackgroundDecorations` node is now named `Foliage` in the saved scene, with a separate `Trees` layer added by the user. Section 18 below records the current scene rather than the original setup template.
- [QUEUED_FIELD_ACTIONS.md](QUEUED_FIELD_ACTIONS.md): context-sensitive tools, deferred queue, FarmerAgent, drag input and verification. This supersedes earlier descriptions of instantaneous player planting/removal/transfer and excluded tilling.
- [STEP_4_1_CROP_VISUALS.md](STEP_4_1_CROP_VISUALS.md): growth stages, normalization, root anchoring and crop-specific seedling scaling.
- [STEP_4_2_FIELD_TOOLS.md](STEP_4_2_FIELD_TOOLS.md): removal/transfer state contracts, input cancellation, setup and verification.
- [STEP_4_3_CAMERA_UX.md](STEP_4_3_CAMERA_UX.md): implemented camera/input contracts, HUD wiring, verification, and remaining device checks.
- [STEP_4_4_CROP_LIFECYCLE.md](STEP_4_4_CROP_LIFECYCLE.md): growth/stress formulas, lifecycle state, harvest receipts and UI setup.
- [WEATHER_AND_SOIL_TOOLS.md](WEATHER_AND_SOIL_TOOLS.md): Inspector tuning, hydration equations, Water/Fertilize actions, transaction order and latest test status.

### Stack and entry points

- Godot 4, strictly typed GDScript 2.0, Resources, RefCounted state/models, signals, Node2D, TileMapLayer, Camera2D, and Control-based UI.
- Last tested engine: `4.7.2.stable.official.ed1daf0bf`; project declares Godot `4.7` and Mobile features. Use the same version initially to avoid migration differences.
- Mobile renderer; Windows rendering driver is configured as D3D12. Reassess renderer compatibility on another OS/device through the Editor.
- Project name: `Test Game Project`.
- Main scene: `res://field_prototype.tscn`; configured by UID in `project.godot`.
- Viewport: 1280 × 720; `canvas_items` stretch with expanding aspect.
- Current project root: `C:\Users\User\Documents\test-game-project\test-game-project`. Run project commands in this directory, which contains `project.godot`.
- Current verified executable: `C:\Program Files\Godot\Godot.exe.exe` (machine-specific, not a project dependency).

## 2. Architecture and mandatory conventions

There are **four layers**. The discrete Simulation layer is now integrated into the playable turn loop.

| Layer | Location | Owns | Must not depend on |
|---|---|---|---|
| Data | `src/data/` | Definitions, catalogs, passive state, validation/copy helpers; future persistence schemas | Presentation or gameplay controllers |
| Simulation | `src/simulation/` | Pure RefCounted geometry, epidemic mathematics, and environmental responses | Logic, UI, Node2D, TileSet |
| Game Logic | `src/logic/` | Field initialization, planting rules, growth, discrete turns, removal and transactional transfer; future rewards/outcomes | Tile atlas coordinates or texture paths |
| Presentation | `src/presentation/` | Rendering, input intents, HUD, inspector, composition/presenter wiring | Direct mutation of authoritative simulation/game state |

Key rules:

1. **PCI protocol:** before implementing a new feature, propose touched layers, exact script/asset paths, formulas and edge cases, then wait for explicit approval. Existing authorized fixes can proceed. This handoff does not approve new simulation formulas.
2. Use explicit types for variables, properties, parameters, return values, collections, and enum selectors. Put `class_name` before `extends` consistently with this project.
3. Execute environmental, growth, and epidemic updates on discrete turns/ticks. Never run simulation calculations in `_process()`.
4. Inject scenes, textures, resources, and node references through `@export`. Editor scaffolding may reference the script it installs; gameplay scripts must not hardcode asset loads.
5. Never generate or hand-patch raw `.tscn` or `.tres` text. Use the Godot Editor, EditorScript node APIs, ownership, and Godot serialization. The concern is malformed serialized references/UIDs; `.tscn` itself is a text format, not a binary file.
6. Shared enum identifiers belong in `SimulationEnums`; preserve numeric values for future save compatibility. Avoid circular dependencies and built-in identifier collisions. A prior enum parse error caused a cascade across dependent resources; the user confirmed the fix compiled cleanly. The exact original offending token is not recorded here.
7. Validation returns `PackedStringArray` and reports invalid/non-finite values without silently clamping or mutating data. Empty rule arrays are neutral. Partial catalogs are allowed during authoring; null entries and duplicates are errors.
8. Scene creation is editor-time for persistent UI, while **playable field tile generation is intentionally runtime**. `FieldWorldView` paints the logical grid into `Terrain` (currently 81 cells); do not replace this with manually maintained tile nodes. Authored scenery outside the field is separately saved and must never be cleared by the runtime renderer.

### Rules versus artwork

`TerrainData` and `TerrainDatabase` define plantability and allowed crops. `CropData` and `CropDatabase` define crop identity, growth, immunity, and tolerance requirements. `TerrainTileVisualMap` is exclusively a Presentation mapping from terrain identity to TileSet source ID, atlas coordinates, and alternative tile.

**Approved Step 4.1 exception:** `CropData` carries four-entry `growth_stage_source_ids: Array[int]` and `growth_stage_atlas_coords: Array[Vector2i]` arrays as Presentation metadata. `copy()` duplicates them independently. Their TileSet references are validated by `FieldWorldView`, not interpreted by Logic or Simulation. Keep terrain visual mapping in Presentation.

Changing terrain artwork must never change planting or disease behavior. Changing allowed crops is a data-authoring operation on `TerrainData.allowed_crops`, not an atlas-coordinate conditional in gameplay code.

## 3. Code inventory

### Data scripts (completed)

All paths in this table are under `src/data/`.

| Script | class_name | Key API / responsibility |
|---|---|---|
| `enums/simulation_enums.gd` | SimulationEnums | Shared crop, disease, terrain, compartment, algorithm, nutrient, abiotic, neighborhood and FieldActionKind enums |
| `resources/soil_state.gd` | SoilState | Macro/micro and unified `get_nutrient()` / `set_nutrient()` accessors; `validate()`, `copy()` |
| `resources/abiotic_state.gd` | AbioticState | Field-wide temperature, humidity, light, pressure; `validate()`, `copy()` |
| `resources/float_range.gd` | FloatRange | Inclusive min/max interval; `validate()`, `copy()` |
| `resources/nutrient_rule.gd` | NutrientRule | Nutrient selector, optimal range, weight; `validate()`, `copy()` |
| `resources/abiotic_rule.gd` | AbioticRule | Factor selector, optimal range, weight; `validate()`, `copy()` |
| `resources/crop_data.gd` | CropData | Identity, growth ticks, base immunity, optional tolerance/requirement arrays, approved four-stage visual metadata; `validate()`, `copy()` |
| `resources/disease_data.gd` | DiseaseData | Rates, default algorithm, target crop, neighborhood, trigger arrays; `validate()`, `copy()` |
| `resources/transmission_modifier_profile.gd` | TransmissionModifierProfile | Optional temperature/humidity/N/K response parameters and caps; `validate()`, `copy()` |
| `resources/terrain_data.gd` | TerrainData | `is_plantable`, `allowed_crops`; `validate()`, `copy()` |
| `databases/crop_database.gd` | CropDatabase | `get_crop()`, `has_crop()`, `validate()` |
| `databases/disease_database.gd` | DiseaseDatabase | `get_disease()`, `get_diseases_for_crop()`, `validate()` |
| `databases/terrain_database.gd` | TerrainDatabase | `get_terrain()`, `has_terrain()`, `validate()` |
| `state/field_cell_state.gd` | FieldCellState | Passive per-cell state; `reset_crop_state()`, `is_mature(crop_data)`, `validate()`, `copy()` |
| `state/field_grid_state.gd` | FieldGridState | Row-major cell container, shared environment; `initialize()`, `is_in_bounds()`, `get_cell()`, `set_cell()`, `validate()`, `copy()` |
| `state/field_action.gd` | FieldAction | Detached queued intent; action ID/kind, source/target, crop/additions, visit phase, revision stamps, `copy()`, `stop_coordinates()` |

Authored resources present: crop and terrain catalogs; sugarcane, rice, corn, dry-soil, paddy-mud, and grass definitions. The interactive setup additionally saved `src/data/resources/diseases/rice_blast.tres` and `src/data/databases/default_disease_database.tres`. These are demonstration definitions; nine empirically calibrated disease definitions are not complete. A completed schema is not empirical calibration. SaveData and benchmark-result schemas are not implemented.

### Logic, Simulation, and Presentation

| Script | Class / key API |
|---|---|
| `src/simulation/grid/grid_neighborhood.gd` | GridNeighborhood: static `get_neighbor_coordinates()`, `get_distance_in_tiles()` |
| `src/simulation/simulation_controller.gd` | SimulationController: `validate_turn()`, `process_turn() -> bool`, override/filter/RNG configuration, staged commits and cap diagnostics |
| `src/simulation/models/compartment_math.gd` | CompartmentMath: bounded probability conversion, fractions, one-hot synchronization, continuous paired flows |
| `src/simulation/models/spatial_sir_model.gd` | SpatialSIRModel: `evaluate()` using final infection hazard |
| `src/simulation/models/spatial_seir_model.gd` | SpatialSEIRModel: `evaluate()` with exposed/incubation stage |
| `src/simulation/models/stochastic_ca_sir_model.gd` | StochasticCASIRModel: seeded categorical transitions with synchronized fractions |
| `src/simulation/models/transmission_modifiers.gd` | TransmissionModifiers: `evaluate()`, `needs_crop()`, typed Result with multipliers/rates/cap flags |
| `tools/repair_terrain_atlas.gd` | One-time Godot-API repair, already applied; not a routine pre-test operation |
| `tools/run_tests.py` | Strict eighteen-test runner; rejects errors, warnings, failures, and missing PASS markers |
| `addons/test_harness/plugin.gd` | Environment-gated editor test harness using normal editor lifecycle |
| `src/logic/grid/field_grid_queries.gd` | FieldGridQueries: static `can_plant()`, `validate_terrain_assignments()` |
| `src/logic/farming/farming_controller.gd` | FarmingController: existing farming/turn/snapshot APIs plus `enqueue_action()`, `action_error()`, `get_current_action()`, `get_queued_coordinates()`, `arrive_at_action()`, `cancel_actions()` |
| `src/logic/turns/turn_controller.gd` | TurnController: `advance_turn()`, `reset_clock()`, `try_set_algorithm_override()` |
| `src/presentation/world/terrain_tile_visual.gd` | TerrainTileVisual: terrain/source/atlas/alternative mapping entry |
| `src/presentation/world/terrain_tile_visual_map.gd` | TerrainTileVisualMap: `get_visual()`, `validate(tile_set)` |
| `src/presentation/world/field_world_view.gd` | FieldWorldView: `render_field()`, `render_grid()`, `render_crops()`, `validate_crop_visuals()`, `get_growth_stage()`, `refresh_crops()`, `frame_field()`, coordinate conversion, `_unhandled_input()` |
| `src/presentation/world/crop_debug_overlay.gd` | CropDebugOverlay: `show_snapshot()`, `get_cell_draw_position()`, `_draw()` |
| `src/presentation/world/farmer_agent.gd` | FarmerAgent: procedural character/foot marker, `walk_to()`, `stop()`, `arrived`; no state mutation |
| `src/presentation/world/field_selection_overlay.gd` | FieldSelectionOverlay: terrain-aligned eligibility/selection/queue diamonds and pulsing alpha |
| `src/presentation/world/crop_shadow_overlay.gd` | CropShadowOverlay: small procedural ground shadows, snapshot-driven occupied coordinates |
| `src/presentation/world/field_terrain_preview.gd` | FieldTerrainPreview: editor-only playable preview and optional background preview; no generated cells serialized |
| `tools/setup_manual_world.gd` | One-time editor setup: 9×9 field, disable automatic grass, remove empty fill node, label/reorder editing nodes; inspect current renamed nodes before rerunning |
| `src/presentation/world/field_prototype_presenter.gd` | FieldPrototypePresenter: composition root; Inspect/Plant/Shovel/Move modes, pending move selection, UI intent routing and snapshot refresh |
| `src/presentation/ui/inspectors/tile_inspector_view.gd` | TileInspectorView: `display_cell()`, `clear_display()`, `validate_configuration()`, `close_requested`, `seed_infection_requested`, `set_seed_available()` |
| `tools/setup_disease_playtest.gd` | EditorScript: creates missing demonstration resources, validates existing ones, bakes controls, wires references, saves through Godot APIs |
| `tools/setup_crop_growth_visuals.gd` | EditorScript: normalizes 12 textures, reuses source IDs, saves crop resources and scene via Godot APIs |
| `tools/crop_texture_normalizer.gd` | Editor-time cleanup, shared mature-height budget, stage scaling, bottom-center root origin |
| `tools/setup_field_tools.gd` | EditorScript: runs HUD baker and saves Shovel/Move bindings while preserving scene UID |
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
- AbioticState is field-wide; `temperature_celsius` defaults to 25°C, an uncalibrated placeholder, and must be finite and at least −273.15°C. It is copied with snapshots.
- Crop nutrient requirements and disease nutrient susceptibility rules use a **healthy/resistant inclusive interval**. Values outside it can incur penalties, allowing deficiency and excess effects.
- Disease abiotic trigger intervals are **disease-favorable**: inside the interval increases pressure relative to a neutral baseline.
- Missing modifier profiles and missing nutrient intervals are neutral. The approved optional temperature/humidity/N/K formulas are implemented below; generic rule arrays and base immunity are not additionally applied. Calibration remains outstanding.

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
- Implemented kernel: `exp(-distance_decay * euclidean_distance_in_tiles)` inside the chosen neighborhood. Transmission uses the unnormalized sum of weighted infected fractions (continuous) or infected one-hot indicators (CA), restricted to compatible hosts carrying the same disease.
- Grass is not a crop host but does not block dispersal geometry.

## 5. Playable prototype behavior and scene wiring

Current saved field: **9 × 9**, `terrain_bands = [GRASS]` (`[2]`), coordinates X/Y 0–8. The FarmingController script still has legacy 9×6/three-band defaults, overridden by the scene. Dry soil supports sugarcane/corn; paddy mud supports rice; grass is unplantable and has null soil. Players first dig grass, and use Water Bucket for rice plots. Plantable cells require independent valid SoilState instances. Preserve the saved scene's explicit configuration rather than restoring old band fixtures.

Planting is free on eligible empty cells. Next Turn advances discrete growth, capped at CropData.growth_ticks. Maturity is derived with `is_mature(crop_data)`. Epidemic progression runs after growth. Step 4.4 adds mature-crop harvesting with a yield-quality receipt. Inventory/currency rewards, treatments and win/loss remain unimplemented. `clear_crop()` resets state without harvesting.

```text
FieldPrototype (Node; FieldPrototypePresenter)
├── FarmingController (Node)
├── TurnController (Node)
├── WeatherManager (Node)
├── SoilToolController (Node)
├── World (Node2D; FieldWorldView)
│   ├── BackgroundTerrain (TileMapLayer; authored ground)
│   ├── Foliage (TileMapLayer; authored; background_decorations export points here)
│   ├── Trees (TileMapLayer; authored; shares Foliage's saved TileSet)
│   ├── TerrainPreview (editor-only 9×9 guide)
│   ├── Terrain (TileMapLayer)
│   ├── GrassOverlayLayer (runtime grass tufts on playable cells)
│   ├── Crops (TileMapLayer; normalized growth artwork)
│   ├── CropOverlay (Node2D; CropDebugOverlay; hidden by default)
│   ├── CropShadows (Node2D; procedural)
│   ├── FarmerAgent (Node2D; procedural placeholder)
│   ├── SelectionOverlay (Node2D; eligible/selected/queued diamonds)
│   └── Camera2D
└── HUD (CanvasLayer)
	├── CameraZoomButton, HarvestButton, WaterButton, FertilizeButton, WaterBucketButton
	├── Panel (PanelContainer)
	│   └── Margin / Controls
	│       ├── TurnLabel, SelectedCropLabel, StatusLabel
	│       ├── CropButtons / SugarcaneButton, RiceButton, CornButton, RemoveButton, TransferButton
	│       ├── NextTurnButton
	│       └── AlgorithmSelector (OptionButton)
	└── TileInspectorPanel (PanelContainer; TileInspectorView)
		└── Margin / Layout
			├── Header / TitleLabel, CloseButton
			├── SeedInfectionButton
			└── Scroll / Content
				├── Terrain, soil, crop, growth, disease and state labels
				├── GrowthBar
				└── Compartments (GridContainer): five label/bar pairs
```

Input and update flow:

1. World converts mouse/touch viewport coordinates through the TileMapLayer transform and `local_to_map()`. Release emits `cell_clicked(Vector2i)` or ordered `cells_selected(Array[Vector2i], action_kind)` after eligible-tile filtering; no farming mutation happens on press/release.
2. Presenter starts in Inspect mode with no crop button selected. Selecting a crop enters Plant mode and closes the inspector. Clicking that selected crop again returns to Inspect mode.
3. Presenter builds a FieldAction and calls `enqueue_action()`. Inspect remains immediate and read-only. Shovel locks each drag to occupied-crop removal OR empty-grass digging. Move first selects a source, then queues a compatible destination. Bucket, planting, harvest, soil watering and fertilizing also queue.
4. Presenter directs FarmerAgent to an edge-adjacent standing point. Arrival reports the task ID and logical stop to `arrive_at_action()`. Logic revalidates and commits; transfer visits source then destination and commits both endpoints only at delivery. Queue signals are `action_queue_changed`, `action_finished`, and `queued_harvest_completed`, alongside the existing field/cell signals.
5. Presenter refreshes terrain, crop artwork, shadows, grass tufts, eligibility and an open inspector without changing authoritative state or reframing the camera. Signal connections are guarded against duplicates.
6. Clicking a selected move source cancels that selection. Tool changes/Escape cancel uncommitted selection, not already queued work. Next Turn is disabled and Logic rejects advancement while work is queued. GUI/focus cancellation and two-finger camera gestures cannot accidentally submit a drag.

`TileInspectorView.display_cell(cell_state: FieldCellState, crop_data: CropData)` accepts a **cell**, not FieldGridState. It displays terrain, pH/NPK, crop growth/maturity, optional active disease name, categorical state, removal outcome, and all five fraction percentages. Invalid values are flagged. DiseaseDatabase is optional; unresolved active IDs are shown explicitly. Step 4.4 adds separate vitality and yield-quality scalars and displays them with crop growth; local soil moisture is also displayed.

The debug overlay is hidden in the saved scene; actual crop artwork is rendered on `World/Crops`. Optional overlay positioning uses TileMapLayer.map_to_local() with transforms into overlay space. Snapshot refresh queues redraw; valid fonts/fallback handling and mature-color markers are implemented.

## 6. Tile assets and resolved atlas issue

Temporary textures are under `assets/art/tilesets/terrain/`. Actual filenames currently have double extensions: `dry_soil.png.png`, `paddy_mud.png.png`, `grass.png.png`.

Current saved TileSet footprint remains **(276, 140)**. Inspected ground atlas regions are dry soil **512×478**, grass **512×512**, and paddy **512×470**, with ground texture origins `(4, -14)`. Earlier 3500×3500 source/512×512-region descriptions are historical; the user has replaced artwork and edited imports. Re-measure actual images and regions before migration. The proposed 128×64 footprint in section 19 has not been applied.

| Terrain | Source ID in current visual map | Atlas coords | Alternative |
|---|---|---|---|
| DRY_SOIL | 0 | (0, 0) | 0 |
| GRASS | 1 | (0, 0) | 0 |
| PADDY_MUD | 2 | (0, 0) | 0 |

Each image is a separate atlas source. Never use `(0,1)` or `(0,2)` as terrain selectors. Source IDs are presentation-only and may change when reauthoring assets.

**Resolved:** the saved prototype previously contained stale `(0,1)` and `(0,2)` atlas properties. `tools/repair_terrain_atlas.gd` rebuilt its three single-tile sources through Godot APIs and serialized the scene, explicitly preserving main-scene UID `uid://beit4bfuaevfp`. Fresh strict tests now load without atlas errors. The user confirmed reloading the scene in the Editor. This was saved resource data, not test-runner cache; no routine cache deletion is needed.

### Completed Step 4.1 crop artwork

**Historical static-art baseline:** the measurements and single-image assumptions below describe Step 4.1, not the latest animation strips. Section 14 records the subsequent animation normalization. The saved scene currently uses 20 FPS for twelve crop atlas animations, while the test/setup contract expects eight. Preserve artwork and reconcile intended animation behavior before regenerating assets; do not restore the old static baseline.

- Separate crop TileSet with 12 atlas sources: Rice IDs 0–3, Corn 4–7, Sugarcane 8–11; all atlas coordinates `(0, 0)`. IDs are saved visual mappings, never gameplay rules.
- Growth duration is `CropData.growth_ticks`. Stage 0: progress < 1/3; Stage 1: [1/3, 2/3); Stage 2: [2/3, 1); Stage 3 only when elapsed >= duration. The 25%/50%/75% staging proposal was superseded. No `growth_duration` property or stored visual-stage state was added.
- Sources remain under `assets/art/tilesets/crops/{rice,corn,sugarcane}/`. Generated compressed ImageTexture `.res` files are under `assets/art/tilesets/crops/normalized/`; retain them when copying the project. Original PNGs remain unchanged.
- Cleanup removes nearly transparent residue and tiny disconnected specks before trimming. One height budget per crop accounts for all four aspect ratios, within 2.8 × tile height and 95% of tile width. Stage scale is **35%, 60%, 85%, 100%**, applied after fitting. **Corn and Sugarcane Stage 0 receive an additional 0.5 multiplier**; do not remove this approved correction or normalize every trimmed sprite back to full size.
- A shared 270 × 400 frame canvas does not imply equal artwork size. Historical static visible heights were Rice **110/188/266/314**, Corn **68/234/332/392**, Sugarcane **62/214/304/358**. Use section 14 for the later animation-wide measurements; recheck after asset changes.
- `texture_origin` derives from the final visible bottom-center minus half the canvas dimensions. Roots land at logical tile center, with at most half-pixel horizontal rounding; the old +14 crop offset is obsolete. Soil/terrain alignment is independent of crop height.
- Re-run `tools/setup_crop_growth_visuals.gd` only when regenerating visuals. It saves the generated resources, three CropData resources and scene through Godot APIs. It is not an Undo operation. It registers generated resource UIDs before saving scene references and preserves the main-scene UID.

### Completed Step 4.2 management actions

- Shovel (`TOOL_REMOVE`) destroys an occupied crop without advancing time or giving rewards. `remove_crop()` rejects empty/out-of-bounds targets and delegates to `clear_crop()`. Empty cells have zero growth and all five fractions zero, no active disease, and categorical S/NONE. Soil and terrain remain.
- Move (`TOOL_TRANSFER`) now queues a two-stop farmer task after two plot selections. The destination must be empty and permitted by the existing terrain/crop/soil validation. The underlying atomic transfer copies the crop payload, not its soil or location: identity, growth ticks/remainder, vitality, yield-quality loss, active disease, categorical state/outcome and exact fractions survive. The visible growth stage is derived again from those same ticks.
- Transfer stages a copied grid, validates it and commits once at destination arrival. Both endpoints are updated before source/destination `cell_changed` signals fire. Invalid moves do not mutate the grid or emit changes. The farmer walks between stops, but the crop itself has no carried/interpolated sprite and actions do not advance growth.
- `FieldWorldView` erases vacant coordinates via `TileMapLayer.erase_cell()` and refreshes occupied coordinates from snapshots. No authoritative state is mutated by Presentation.
- Removing an infected crop removes that host and its infection contribution; empty ground is not a new geometric barrier to dispersal. Transplanting does not cure disease.
- Shovel/Move buttons are persistent HUD nodes baked by `tools/bake_ui_to_scene.gd`. `tools/setup_field_tools.gd` runs the baker and saves through the Editor; its setup has already been executed.

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

Verification history: Step 4.2 passed nine tests; Step 4.3B passed eleven; a later crop-animation checkpoint passed fifteen. The queue checkpoint's full run was 16/17, failing only the twelve animation-speed checks. Subsequent targeted camera, queue, grass-overlay, manual-background and editor/runtime-preview runs passed at their implementation checkpoints. The runner now lists eighteen tests, but it has not had a complete verified run against the current user-authored scene. No tests were rerun for this documentation-only refresh; physical Android portrait/landscape/gesture/safe-area checks remain outstanding.

Current test-context caveats:

- Saved crop animations still use 20 FPS versus the test's eight; do not change either without confirming the intended speed.
- All-grass 9×9 initialization means older saved-scene tests cannot simply find dry/paddy plots. A later crop-visual capture produced missing-eligible-cell/planting failures for this reason. Tests should prepare an explicit isolated terrain fixture or exercise digging/conversion; do not restore the user's scene merely to satisfy old assumptions.
- The user has since saved `camera_center_offset = (0, -260)`, renamed decorations to `Foliage`, added `Trees`, and painted scenery. Earlier camera assertions about zero offsets and background assertions about blank authored cells require review before interpreting fresh failures. These are inspection observations, not new test results.
- Earlier atlas errors were absent from the later successful targeted runs. Newly edited assets have not been re-certified by this documentation pass.

| Executable test | Coverage |
|---|---|
| `tests/logic/field_prototype_smoke.gd` | Core field, terrain, planting and turn behavior |
| `tests/logic/field_scene_integration.gd` | Native clicks, Inspect/Plant toggles, close_requested exactly once, live snapshots, preserved anchors/offsets |
| `tests/logic/disease_playtest_test.gd` | Fresh saved-scene load, external catalog wiring, native seed-button clicks, valid/invalid seeding, algorithm rollback, and spread |
| `tests/logic/simulation_scaffold_test.gd` | Reset/clear/replant, growth → simulation → UI ordering, pre-growth rejection |
| `tests/simulation/epidemiology_models_test.gd` | Fluxes, staging, conservation, seeded CA, switching, ambiguity, rollback |
| `tests/simulation/transmission_modifiers_test.gd` | Neutral responses, thresholds, caps/overflow, recipient effects, conservation and reproducibility |
| `tests/presentation/tile_inspector_builder_editor_test.gd` | Real builder, Undo/Redo, ownership, bindings, serialization and missing-HUD reconstruction |
| `tests/presentation/crop_growth_visuals_test.gd` | Stage boundaries, saved atlas wiring, normalization, per-crop seedling ratios, root alignment, planting/turn rendering and erasure |
| `tests/logic/field_management_test.gd` | Native Shovel/Move input, terrain/occupancy rejection, exact payload preservation, soil locality, removal/reset and tool-switch cancellation |
| `tests/presentation/camera_zoom_test.gd` | Zoom limits, wheel/pinch ratios, single-tap release, multi-touch and drag suppression |
| `tests/presentation/camera_ux_test.gd` | Pan scaling/bounds, focal anchoring, PC/touch drags, UI gesture isolation, saved Zoom/Reset action, and resize |
| `tests/simulation/crop_growth_test.gd` | Nutrient/pH/moisture growth stress, vitality and harvest |
| `tests/logic/weather_soil_tools_test.gd` | Weather turn ordering, moisture bounds, rollback and soil actions |
| `tests/presentation/terrain_preview_editor_test.gd` | Editor preview generation and refresh |
| `tests/presentation/terrain_preview_runtime_test.gd` | Runtime isolation of editor preview |
| `tests/presentation/grass_overlay_test.gd` | Grass-only placement, stable redraws, clearing and invalid optional configuration |
| `tests/logic/queued_field_actions_test.gd` | Deferred mutations, conversions, reservations, stale tasks, source/destination visits, drag locks, highlights and camera gesture coexistence |
| `tests/presentation/background_layers_test.gd` | Authored tile/prop preservation, independent terrain resources, save/reload, logical-grid isolation and optional fill fixtures |

Run from the project root:

```powershell
python tools/run_tests.py --godot 'C:\Program Files\Godot\Godot.exe.exe'
```

Replace the executable path on another device. Logs use absolute paths under `.godot`. Ensure project imports are complete and editor settings/log directories are writable.

**Do not launch the editor builder test with `--editor --script`.** That combination previously reproduced editor shutdown leaks. The runner starts a normal headless editor with `GODOT_EDITOR_TEST=tile_inspector_builder` or `terrain_preview`; ordinary editor sessions do nothing. Setup flags are `GODOT_PLAYTEST_SETUP=1`, `GODOT_CROP_VISUAL_SETUP=1`, `GODOT_FIELD_TOOLS_SETUP=1`, and `GODOT_MANUAL_WORLD_SETUP=1`. Use only one setup/test flag at a time. Setup intentionally saves resources; the strict runner clears all setup flags. Test helpers are released before normal editor teardown. The manual/general setup scripts need review for current renamed scenery nodes before rerunning (section 18).

Temporary scene instances are freed; undo references are cleared before freeing detached HUD nodes; selection is cleared and deferred updates finish before exit. Grids own cells, cells do not point back to grids, and neighborhood arrays are local. No RefCounted ownership cycle was found. No leak diagnostics are suppressed. See [TESTING.md](TESTING.md).

Transfer checklist:

- Copy the full project, including project.godot, addons, source, `.gd.uid` sidecars, authored scenes/resources, original assets, all 12 generated normalized crop `.res` textures, import settings, tools, tests, and docs.
- Preserve relative paths and filename case. `.godot` is normally regenerated, but the current scene contains direct imported `.ctex` paths: verify those resolve after importing the original images. Prefer reassigning source textures in the Editor if regeneration leaves broken references.
- Open/import the project and let script class registration finish before playtesting.
- Open the prototype, verify catalogs/visual mappings, run the UI baker only if needed, save, and play with F5 (or F6 for the prototype scene).
- Confirm dry-soil and rice permissions, grass rejection, maturity cap, Inspect/Plant toggling, inspector refresh, close behavior, small seedlings and 100%-only mature art, Shovel removal, and compatible/incompatible Move destinations.
- Git is initialized. Current inspected HEAD is **`3558a75` (`fix errors`)**. The worktree contains extensive modified/untracked implementation, documentation and user artwork; it is not clean. `origin` is `https://github.com/spatrickjs/test-game-project.git`; remote reachability and push status were not checked. This documentation update is not a commit or push.

## 9. Immediate next steps and remaining scope

### Completed Phase 3 runtime contract

- `SimulationController.algorithm_override = -1` uses each disease default; 0/1/2 select SIR/SEIR/CA without changing DiseaseData.
- `active_disease_filter = -1` considers all registered diseases. A selected DiseaseId restricts updates to that disease; cells carrying other diseases are frozen and do not contribute its pressure.
- `time_step = 1.0` must be positive and finite. `rng` is injectable/seedable; compare algorithms using copies of the same initial grid and explicit RNG state.
- Continuous flows use `1 - exp(-rate * time_step)` and old compartments only. SIR: S → I; SEIR: S → E → I. Both include I → immune/dead and immune → S. Newly infected/exposed/recovered mass cannot progress again within the same tick.
- CA performs at most one categorical transition per tick, with a separate mortality decision and exact probability endpoints.
- SIR/CA reject any E > 0. CA requires exact one-hot fractions; there is no implicit projection of mixed stands. One-hot continuous state is synchronized to categorical state when entering CA.
- Evaluation reads a detached snapshot, traverses canonical coordinates/disease IDs, and stages all results. Only validated results commit; failed evaluation restores RNG state. Compartment fractions conserve total mass within floating-point tolerance.
- Healthy cells exposed to multiple positive disease hazards are rejected until an explicit disease filter resolves the ambiguity. Active disease identity persists through recovery/waning.
- `FieldCellState.reset_crop_state()` uses `has_crop` to choose healthy S=1 versus empty all-zero fractions; soil/terrain/coordinates are preserved.
- `FarmingController.advance_simulated_turn()` validates before mutation and rolls back the turn on failure. The current integrated order is **weather/moisture (if configured) → growth → epidemic evaluation/commit → turn increment → turn_completed → UI snapshot**. Pending player tasks block turn advancement.
- An empty disease catalog is a safe epidemic no-op. The turn controller provides an empty default Resource. No infections arise spontaneously without seeded infection pressure. The saved prototype overrides the empty catalog with the external default Rice Blast catalog and includes the patient-zero action described below.

See [STEP_3_3_SIMULATION.md](STEP_3_3_SIMULATION.md) for the implementation contract.

### Completed environmental modifiers

`DiseaseData.transmission_modifier_profile` optionally references `TransmissionModifierProfile`. Temperature response defaults off, humidity/N/K strengths default to zero. No profile means neutral modifiers.

For temperature T, favorable interval [Tmin,Tmax], positive falloff ΔT, and weather floor m:

```text
dT = max(Tmin - T, 0, T - Tmax)
MT = 1 - (1 - m) * clamp(dT / ΔT, 0, 1)
MH = 1 + humidity_sensitivity * clamp((H - H0) / (1 - H0), 0, 1)
weather = clamp(MT * MH, minimum_weather_multiplier, maximum_weather_multiplier)

excess_N = clamp((N - Nmax) / (1 - Nmax), 0, 1)  # zero when Nmax == 1
MN = 1 + nitrogen_excess_strength * excess_N
dK = max(Kmin - K, 0, K - Kmax)
MK = 1 - potassium_protection_strength * (1 - clamp(dK / potassium_falloff, 0, 1))
nutrient = MN * MK

effective_beta = min(beta_cap, base_beta * weather * nutrient)
hazard = min(hazard_cap, effective_beta * neighbor_pressure)
infection_probability = 1 - exp(-hazard * time_step)
```

N/K intervals come from the recipient crop's nutrient requirement rules and values from the recipient cell's soil. Missing intervals are neutral. FarmingController supplies the crop catalog; direct simulation callers must assign `crop_database` when nutrient strengths are enabled. Generic rule weights, susceptibility arrays, abiotic triggers and base_immunity are not reapplied.

All three models now accept the final **hazard**, not raw neighbor pressure. Products are overflow-safe. Separate beta/hazard caps default to 1,000,000 inverse-time units in an attached profile, an authoring choice rather than a fitted biological value. The full profile defaults and constraints are documented in [ENVIRONMENTAL_MODIFIERS.md](ENVIRONMENTAL_MODIFIERS.md).

The evaluator returns multiplier/rate values and cap flags. Controller `weather_cap_count`, `beta_cap_count`, and `hazard_cap_count` report evaluated cell/disease computations for successful turns, not infection counts; failures discard them. Include these diagnostics in future benchmarks.

**Scientific scope:** these curves are phenomenological assumptions awaiting calibration. Humidity is not a complete leaf-wetness model, normalized soil values need empirical mappings, and multiplicative N/K responses omit explicit N–K interaction. Do not enable identical responses for all nine diseases without evidence. References and limitations are preserved in the modifier guide.

### Completed interactive disease playtest

The setup was executed and saved, not merely supplied as an unrun script. The main-scene UID remains `uid://beit4bfuaevfp`; new controls are baked with scene-root ownership. Reload `field_prototype.tscn` if it was open during setup, then press F5.

1. In the current all-grass scene, use Shovel to dig adjacent plots, then Water Bucket to convert them to paddy; wait for each queued operation. Select Rice and queue planting on those plots, then wait for the farmer to finish.
2. Click the selected Rice button again to return to Inspect mode.
3. Inspect a clean rice tile and click **Seed Infection**.
4. Advance **Next Turn** and inspect neighboring crop fractions.
5. For CA, select **Stochastic CA-SIR before seeding**. Restart play for a clean board when mixed continuous fractions make switching incompatible.

Saved configuration:

- `src/data/resources/diseases/rice_blast.tres`: Rice Blast targeting Rice, Spatial SIR default, beta 0.6, sigma 0.5, gamma 0.15, xi 0, mortality 0.10, Moore radius 1, distance decay 0.3.
- Attached TransmissionModifierProfile: temperature enabled, favorable interval 20–30°C, humidity sensitivity 0.5; N/K effects disabled pending crop threshold authoring.
- `src/data/databases/default_disease_database.tres` references the external disease resource. TurnController and TileInspectorView share this catalog. All values remain illustrative and uncalibrated.
- Presenter `playtest_disease_id` defaults to RICE_BLAST. The Seed Infection button emits intent to the presenter; FarmingController validates and commits a copied candidate grid, then emits cell_changed.
- Continuous SIR/SEIR patient zero is S=0.8, I=0.2, other fractions zero. CA patient zero is one-hot I=1 with matching categorical state.
- Seeding requires a clean, fully susceptible, compatible occupied cell with valid state. It rejects repeat seeding and invalid hosts, preserves soil/growth, and does not advance the turn.
- The HUD selector has Disease Default / Spatial SIR / Spatial SEIR / Stochastic CA-SIR. TurnController validates proposed overrides against the board and restores the previous override on failure; the presenter restores the selector and shows the reason.
- Crop artwork indicates growth stage, not disease intensity; the optional debug overlay is hidden by default. Read disease fractions in the inspector. Stochastic spread is not guaranteed on any individual turn.

`tools/setup_disease_playtest.gd` can be run from the Script Editor with Ctrl+Shift+X. It creates missing resources and validates existing ones without overwriting them; rerun verification confirmed both resource files remained byte-for-byte unchanged. The general baker reuses existing compatible nodes. Setup wires references and saves via Godot APIs, without raw scene/resource text. Headless saves disable thumbnail generation. Loaded non-tool Resource placeholders are validated using transient script instances.

The environment-gated editor harness also supports automated setup using `GODOT_PLAYTEST_SETUP=1`. Unlike tests, setup intentionally saves resources and the scene. Do not combine setup and test flags. New resources are not covered by editor Undo; the baker's node/ownership operations retain Undo/Redo support.

See [DISEASE_PLAYTEST.md](DISEASE_PLAYTEST.md) for the original operational instructions; prepare paddy plots first in the current all-grass scene. Historical fresh-process verification covered native input, saved wiring, algorithm modes and rollback. The disease-playtest test remains in the eighteen-test runner; section 8 describes why old saved-scene fixture assumptions need review.

### Next work: propose and approve before implementation

1. Playtest the saved Rice Blast setup, calibrate its parameters using documented sources, and author the remaining diseases/profiles. The catalog is already wired to both TurnController and the inspector.
2. Propose richer scenario initialization/reset and diagnostic UI for weather, modifiers, and caps. Patient-zero seeding, model selection, four-stage crop visuals, Shovel and Move already exist; do not duplicate them.
3. Specify benchmark protocols: shared initial state and inputs, time step/horizon, seeded repeated runs, grid scales, timings/memory, and separation of rendering from numerical work. No mobile benchmark results or calibrated accuracy claims exist yet.
4. Define metrics, research provenance, SaveData and benchmark schemas, and catalog completeness requirements.
5. Harvest collection and yield quality are implemented in Step 4.4. Propose inventory/currency rewards, treatments, win/loss, or further interactions as separate increments.

Steps 4.1, 4.2, 4.3 and 4.3B have been implemented. Do not describe existing simulation models, environmental modifiers, crop management, or camera controls as pending implementation.

### Approved Step 4.4 implementation

The user approved the crop-lifecycle proposal and harvest operation. `CropGrowthProfile`, `CropGrowthModel`, `HarvestResult`, local moisture and per-cell vitality/fractional growth/quality loss are implemented. The actual logic entry point is `src/logic/farming/farming_controller.gd`; there is no `FieldGrid.gd`. See [STEP_4_4_CROP_LIFECYCLE.md](STEP_4_4_CROP_LIFECYCLE.md). This replaces the earlier pending disease-propagation request with the approved growth/harvest scope.

## 10. Coding, assets, and change discipline

Use snake_case files/methods/properties, PascalCase class names, UPPER_SNAKE_CASE enum members/constants, explicit return types, small components, and descriptive signals. Keep validation diagnostics index-prefixed for catalog entries. Treat shared definition Resources as read-only at runtime and use copies for mutable per-tile state/snapshots.

Reserved/planned locations: `src/logic/autoloads/` for a future typed signal bus if needed; `assets/art/models_3d/blender_source/` for possible Blender sources or prerendered meshes. These are approved organizational destinations, not implemented 3D gameplay or singleton systems. Current art lives under `assets/art/tilesets/terrain/` and `assets/art/tilesets/crops/`, including the generated normalized crop textures.

Use conventional commits for future changes: `feat(ui): bake persistent inspector controls`, `fix(world): validate atlas source coordinates`, `refactor(simulation): separate neighborhood geometry`, `test(logic): cover terrain planting rules`, `docs: update project handoff`. Use `type(scope): concise imperative description`, document behavior and relevant verification, and avoid claiming unrun tests or calibrated research results.

For the next assistant: read this handoff and current scripts first, follow PCI for new work, and keep the four-layer boundary. Continue from the 9×9 manual world and queued actions, preserving the user's painted surroundings, renamed layers, crop scaling and transfer payload semantics. Sections 1, 8 and 16–19 supersede historical continuation notes. Do not rebuild the inspector, restore runtime layout overrides, regenerate artwork, or bypass the normal editor test lifecycle without task-specific reason.


## 11. Current connection and workspace context

- Last connector check: Godot `4.7.2.stable.official.ed1daf0bf` responded and read this project successfully. The connector reported no tracked active Godot process; that does not establish whether a separately launched editor is open.
- `_is_over_ui(screen_pos: Vector2)` in `src/presentation/world/field_world_view.gd` replaces the parameter `position` and its internal reference, avoiding Node2D property shadowing. No behavior was intentionally changed.
- Current inspected HEAD is `3558a75` (`fix errors`); earlier `6ff33f3` and `911994d` references are historical. Preserve all unrelated worktree changes. Modified terrain images and untracked `dry_soil1.png.png`, `grass1.png.png`, `paddy_mud1.png.png`, `foliage/grass_tuft.png`, and `tree/treev1.png` (with import files) are present. Do not assume alternates are unused or delete them. No commit or push was performed in this documentation refresh.
- The saved scene now includes painted tile data on `BackgroundTerrain`, `Foliage` and `Trees`. `background_decorations` references `Foliage`; `Trees` shares its saved TileSet. This naming is newer than the original setup scripts and guides. Runtime exports still resolve, but old setup scripts hardcode `BackgroundDecorations`: inspect/update them before rerunning, or they may recreate/rebind an unwanted layer or fail during reordering. This documentation pass did not run those setup scripts.


## 12. Weather and soil management continuation

The user explicitly approved weather/moisture updates and watering/fertilizing after the earlier exclusions. Root-level WeatherManager and SoilToolController nodes are saved and wired in the prototype; their values are Inspector exports. Water/Fertilize controls are persistent and operate through FarmingController transactions. Weather runs before lifecycle growth and rolls back with a failed turn. Balanced weather defaults preserve baseline moisture; enable fluctuations or change rainfall/evaporation to demonstrate shifts. External climate sources are future hooks with explicit unsupported-mode errors. See [WEATHER_AND_SOIL_TOOLS.md](WEATHER_AND_SOIL_TOOLS.md).


## 13. Editor terrain preview

An editor-only preview is saved as `World/TerrainPreview`, using `src/presentation/world/field_terrain_preview.gd`. It currently shows the **9×9 playable grass field only**, leaving the surroundings for manual painting. Change FarmingController `field_size` or `terrain_bands`; the preview refreshes within 0.25 seconds. Terrain visual mapping and TileSet changes also refresh it. Select TerrainPreview for `Preview Enabled` and `Refresh terrain preview`. The optional `Background Preview Enabled` is saved false; automatic background generation is disabled and its scene node is absent.

The tool reads exported configuration from non-tool Node placeholders; gameplay controllers are not executed in the editor. It draws into an internal, ownerless playable TileMapLayer and, only when explicitly enabled, a separate internal grass preview. Generated cells are excluded from scene serialization and no preview layers or polling are created at runtime. The preview shares ground Y sorting to avoid the floating-thick-tile effect. Runtime field generation remains authoritative. Invalid configuration clears previews and reports a warning; playable previews above 10,000 cells are refused.

`tools/setup_field_tools.gd` originally added/wired the preview through Godot APIs; see section 11 before rerunning it after user node renames. Preview tests cover refresh, band matching, optional background, disabling/invalid configurations, no duplicate/serialized generated layers, and runtime isolation. The 14/15 and 15/15 checkpoints are historical; section 8 records the latest verification context.


## 14. Historical crop-animation normalization repair

The 35 reported failures combined obsolete static-image assumptions with a real scale-budget problem. Each texture is an 11-frame, 2970 x 400 strip, containing 270 x 400 atlas frames. Tests had treated the entire strip as a single crop. They now inspect all 132 frames for region dimensions, bounded artwork, eight-FPS timing, stem-base anchoring, stable root footprints and growth-stage proportions.

`tools/crop_texture_normalizer.gd` now derives the shared mature-height budget from the union of every frame in every growth stage. The previous first-frame-only budget allowed a wider later corn seedling frame to impose an independent width reduction. The common budget preserves stage ratios, including the extra 0.5 seedling scale for corn and sugarcane. Root origin uses the first frame's bottom four-pixel stem band rather than the moving canopy bounding box; every saved frame is checked to keep the anchor within its stem base.

`tools/setup_crop_growth_visuals.gd` cleans/reduces each large source frame once, reuses prepared frames, regenerates derived strips and serializes atlas resources through Godot APIs while preserving the scene UID. Source PNG frames are unchanged. Its final full filesystem scan was replaced with a targeted scene update to avoid aborting an unnecessary scan during headless shutdown.

Current maximum visible heights across each animation: Rice 108/188/266/312 px; Corn 58/202/288/338 px; Sugarcane 62/214/302/356 px. Earlier static-art measurements are historical. Synthetic regressions cover a later frame wider than frame zero, seedling-ratio preservation, and rejection of mismatched frame canvases.

Historical verification at this checkpoint: all fifteen strict tests passed, with zero engine warnings/errors. Section 8 supersedes this as the verification status. An additional hidden rendered run of the crop-visual test passed at that checkpoint; seedling and mature screenshots were visually inspected. Reload the scene/resources if the editor still shows cached artwork.


## 15. November 6 FieldWorldView repair and historical blockers

The status below predates queued field actions. The grass overlay was subsequently wired, and later targeted runs did not reproduce those atlas-loading errors. Sections 1 and 8 supersede this historical test count and pending-work list. Current user edits have not had a fresh full run; the animation-speed mismatch remains unresolved.

The user requested a fix to `src/presentation/world/field_world_view.gd`. An added untyped `render_grid(grid_data)` duplicated the existing typed method, preventing compilation. Its placeholder `cell.is_grass`/`cell.position` assumptions also did not match `FieldGridState`/`FieldCellState`.

The duplicate was removed. The existing `render_grid(grid_state: FieldGridState) -> bool` now calls `_render_grass_overlay()` after drawing terrain. The helper reads `cell.terrain_type == SimulationEnums.TerrainType.GRASS` and `cell.coordinates`. The exported overlay/source/atlas/chance settings are preserved, with a 0..1 Inspector range for spawn chance. Decorations use a separate seed-zero RandomNumberGenerator so redraws are repeatable and do not consume the simulation's global random stream. Missing optional layers/sources/tiles safely skip decoration. A mistakenly assigned terrain or crop layer is never cleared. This repair changes Presentation only and does not wire or repair the scene's optional grass overlay.

`tests/presentation/grass_overlay_test.gd` passed (`GRASS_OVERLAY_PASS`), with no engine errors. It covers grass-only placement at full chance, stable redraws, zero-chance clearing, unchanged soil, missing source/tile handling and protection of base terrain. It is registered as the sixteenth test in `tools/run_tests.py`.

The immediately preceding full fifteen-test run exited 1. `field_scene_integration.gd` and `camera_zoom_test.gd` reached their PASS markers, but scene loading emitted atlas errors, so strict validation correctly rejected them. The camera and crop-visual logs each contain 516 `ERROR:` records about out-of-texture/overlapping tiles and missing atlas coordinates (for example `(27, 21)`). `crop_growth_visuals_test.gd` also reports twelve `Saved animation speed` failures; the saved scene contains 20-FPS entries while tests expect eight. Do not equate an individual PASS marker with a clean strict result.

Historical pending items at that time were grass-atlas repair, optional overlay wiring and animation-speed reconciliation. Overlay wiring and later rendering fixes have since been implemented; do not repeat that repair blindly. The current runner has eighteen tests. Logs under `.godot/` include `grass_overlay_test.log`, `field_scene_integration.log`, `camera_zoom_test.log` and `crop_growth_visuals_test.log`; they can be overwritten by later runs and are not a substitute for checking run provenance.

## 16. Queued field actions and farmer continuation

See [QUEUED_FIELD_ACTIONS.md](QUEUED_FIELD_ACTIONS.md) for the implementation contract. Its 16/17 result is a historical queue checkpoint, not certification of later world-authoring edits.

- `FieldActionKind` is a new independent enum in `SimulationEnums`; existing enum numeric IDs are unchanged. `FieldAction` is passive copied task data.
- FarmingController owns the FIFO queue. `enqueue_action()`, `action_error()`, `get_current_action()`, `get_queued_coordinates()`, `arrive_at_action()` and `cancel_actions()` provide validation, reservations, copied task snapshots, arrival commits and cancellation. Per-cell revisions reject stale tasks; invalid tasks clear and let the queue continue.
- Shovel removes occupied crops exactly as before. On empty grass it creates dry soil with a distinct copy of `initial_soil`. A drag locks to whichever valid context it first encounters, preventing accidental crop removal during digging.
- Water Bucket accepts empty dry soil only and converts it to paddy while preserving soil values. Existing Water adds moisture and Fertilize adds configured nutrients; these are distinct actions. No direct grass-to-paddy conversion is allowed.
- Planting, removal, digging, bucket conversion, transfer, harvest, Water and Fertilize from the HUD are deferred. Immediate Logic APIs remain available to internal callers/test fixtures. Actions do not advance simulation time. Turns are blocked while tasks are queued.
- Transfer reserves both endpoints. The farmer first visits the source, leaving the crop intact, then visits the destination and executes the existing atomic payload transfer. Cancelling after source arrival does not lose the crop. Soil belongs to each location.
- Farmer standing points use the nearest `center + 0.6 * (orthogonal_neighbor_center - center)` in Terrain-local space, transformed to world space. The farmer stops beside the target, not at its center. Straight-line locomotion is visual only; no pathfinding, collision obstacles or carried-crop animation exists.
- FarmerAgent uses procedural drawing and a foot ellipse. A future child `AnimatedSprite2D` can replace the drawing while retaining movement/arrival contracts. Keep feet at the agent origin for sorting and positioning; no sprite migration has been implemented.
- SelectionOverlay uses logical diamond footprints. Eligible tiles have pale green outlines, active selection pulses cyan, queued plots/pending transfer source pulse amber. Single-finger/left-mouse tool drags select; middle mouse and two fingers retain camera control. Mode/GUI/focus changes cancel unfinished selection while queued work continues.
- The arrival signal uses local copies of action ID/stop coordinates so scheduling the next stop during one listener cannot alter values received by later listeners.

## 17. Crop shadows, camera framing and mobile context

`World/CropShadows` uses `crop_shadow_overlay.gd`: three nested translucent ellipses at occupied tile centers, refreshed by `render_crops()`. Defaults are radius `(30, 12)`, offset `(0, 2)`, and color alpha `0.24`; the current scene additionally has a user-authored node scale `(1.3, 1.3)`. Preserve that setting. Shadows disappear/move with crop state and do not affect simulation.

`FieldWorldView.frame_field()` now calculates bounds from playable cell centers (`map_to_local`) and the diamond's half-tile-size vertices transformed through Terrain. It ignores atlas transparent padding and manually painted surroundings. It fits the available viewport minus margins and bottom HUD reserve; the old 0.5 zoom floor was replaced by a small positive guard so small viewports can still fit.

The overview center is `bounds.center + (0, reserved_height / (2 * zoom)) + camera_center_offset`. Positive camera-offset Y lifts the rendered field; negative Y lowers it. `_default_camera_center` stores that adjusted center and remains the clamp/reset anchor. The exported offset defaults to zero, but **the current scene saves `(0, -260)`**. Do not reset that authoring choice during asset migration or interpret an old zero-offset screenshot as the current framing.

Camera/selection coordinates derive from viewport and TileMap transforms, and resizing reframes the field. Automated pan, zoom, touch and resize checks passed during development. Desktop rendered previews used OpenGL compatibility for screenshots without changing the project's Mobile/D3D12 configuration. Physical mobile performance, orientation, notches and navigation-bar safe areas remain unverified; no automatic safe-area adaptation was added.

## 18. Manual world layers, depth ordering and cleanup

Current saved editor-facing nodes:

| Node under World | Current role | Preservation rule |
|---|---|---|
| `BackgroundTerrain` | Painted surrounding ground | Do not clear/rebuild its tile data; leave playable X/Y 0–8 clear |
| `Foliage` | User-renamed original BackgroundDecorations; painted scenery | `background_decorations` references this node; keep its name/binding |
| `Trees` | Additional user-authored scenery layer | Shares the saved Foliage TileSet; editing that TileSet affects both |
| `TerrainPreview` | Transient 9×9 playable guide | Keep enabled while editing surroundings; no generated preview data saved |
| `Terrain` | Runtime playable farm | FieldWorldView regenerates only logical cells here |

`AutomaticGrassBackground` was removed because manual world design was requested. `automatic_background_enabled` defaults false and `background_fill_layer` is unassigned. Optional generation code remains for explicitly configured scenes, not the current manual scene. Unpainted surroundings show the viewport background; manually cover the camera footprint for intended screen aspect ratios.

Thick ground tiles must share the same Z index (currently zero) and Y sorting. Putting the entire farm above all surrounding grass caused the floating-island appearance; shared sorting fixed the edge occlusion. Optional automatic fill skips authored ground positions. Foliage, Trees, crops and farmer currently use Z=2; CropShadows uses Z=1 and SelectionOverlay Z=3. Keep tile layout, footprint and ground alignment consistent across layers.

The original editable ground/decorations TileSets were independently duplicated from playable terrain. Texture files remain shared assets. Current Foliage and Trees intentionally reference the same saved TileSet; independence between every scenery layer is no longer true. Animated foliage can use atlas animation; reusable props can use AnimatedSprite2D/AnimationPlayer scenes with their origin at the ground contact point. These animations do not become movement obstacles or alter spread rules automatically.

Scene cleanup removed only the unused automatic-fill node. CropOverlay remains hidden but referenced by debug/integration paths; GrassOverlayLayer, Crops, CropShadows, SelectionOverlay, FarmerAgent and Camera2D are active runtime nodes. Editor descriptions label roles. Do not delete these merely because they are empty before runtime.

`tools/setup_manual_world.gd` originally saved 9×9/manual settings and node descriptions through Editor APIs (`GODOT_MANUAL_WORLD_SETUP=1`). It refuses to delete a fill node with authored content. Both this script and the general setup still contain the older `BackgroundDecorations` node name; inspect/adapt them before any future use. Do not rerun them merely to refresh documentation.

## 19. Latest discussion: asset replacement and autotiling (not implemented)

The user intends to create new TileMaps/assets and change isometric tile dimensions. They asked whether this breaks gameplay and whether terrain bitmasks can improve transitions. The discussed migration remains pending; **no new tile size, terrain peering data or autotiling render path has been applied**. The current renderer still selects explicit atlas source/coordinates with `set_cell()`.

Proposed art-production starting point, not a fixed project requirement:

| Item | Discussed recommendation |
|---|---|
| Logical ground diamond | 128×64 pixels |
| Per-tile image frame including thickness | 128×96 pixels |
| Example sheet arrangement | 8 columns × 6 rows |
| Example sheet dimensions | 1024×576 pixels, without extra atlas margins/separation |
| Capacity | 48 slots: conventional 47-variant blob layout plus a spare |

The 47-variant recommendation is a restricted single-terrain/background transition scheme, **not every possible multi-material combination**. Grass/dry/paddy junctions, roads, special boundaries and animation frames may require additional art and explicit terrain design. Godot 4 uses TileSet Terrain Sets/peering bits rather than the old bitmask editor. A sheet's size/layout does not configure connections automatically. The earlier reply referenced the [Godot TileSet guide](https://docs.godotengine.org/en/stable/tutorials/2d/using_tilesets.html); this documentation refresh did not recheck external documentation.

Keep ground diamonds aligned consistently within frames; the extra 32 pixels in that proposed frame allow soil thickness below the surface. Transparent image padding, full sprite dimensions and the logical diamond footprint are different quantities. Tall props/crops belong in separate images/sheets. Keep current assets until replacements are verified.

Future migration scope is primarily Presentation/editor resources: synchronize tile size/layout across independent TileSets, update texture origins and crop normalization/roots, review fixed-pixel shadows/agent scale/speed, reposition manually placed props, and verify camera/input/preview on desktop and mobile. Godot coordinates, farming rules and algorithm formulas can remain unchanged. Autotiling would require a deliberate FieldWorldView and editor-preview rendering update, transition artwork, neighbor refresh after conversion and boundary coordination with separately painted layers. Confirm the supplied dimensions and intended connections before implementing.

The core SIR/SEIR/CA and modifier implementations exist, but disease calibration, catalog completion, benchmarks and scientific validation are unfinished. Inventory, economy, quests and art can be added in their appropriate layers without rewriting epidemic models. Mechanics that deliberately change transmission/recovery or introduce barriers/co-infection require a separate approved simulation review. Do not describe the whole research component as 100% finished.
