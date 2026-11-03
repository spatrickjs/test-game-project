# Project handoff: isometric crop disease education game

Last reviewed: **2026-11-04 (Asia/Shanghai)**. This document combines approved design decisions, files inspected in the workspace, and previously reported test results. Paths below are relative to the project root; `res://` means the directory containing `project.godot`.

## 1. Overview and continuation checkpoint

Undergraduate Computer Science thesis: a 2D isometric educational mobile game explaining how crop diseases spread and how field management can prevent or reduce them. The intended audience is the general public. Development follows incremental prompting and **game-first order**: playable terrain, planting, growth, and inspection precede epidemiological mathematics.

**Current checkpoint:** Phase 1, Phase 2 (including the inspector and persistent UI), and Phase 3 Steps 3.1–3.3 are implemented. Switchable Spatial SIR, Spatial SEIR, stochastic CA-SIR, transactional turn integration, and optional environmental transmission modifiers are complete. The latest strict run passed all seven executable tests with zero warnings/errors. The saved prototype also includes a Rice Blast catalog, patient-zero inspector button, and transactional algorithm selector. Atlas serialization and headless-editor shutdown leaks are resolved. Next work is disease/scenario authoring, calibration and benchmark design, subject to PCI approval; do not reimplement completed mechanics.

### Stack and entry points

- Godot 4, strictly typed GDScript 2.0, Resources, RefCounted state/models, signals, Node2D, TileMapLayer, Camera2D, and Control-based UI.
- Last tested engine: `4.7.2.stable.official.ed1daf0bf`; project declares Godot `4.7` and Mobile features. Use the same version initially to avoid migration differences.
- Mobile renderer; Windows rendering driver is configured as D3D12. Reassess renderer compatibility on another OS/device through the Editor.
- Project name: `Test Game Project`.
- Main scene: `res://field_prototype.tscn`; configured by UID in `project.godot`.
- Viewport: 1280 × 720; `canvas_items` stretch with expanding aspect.
- Current project root: `C:\Users\User\Documents\test-game-project\test-game-project`. The outer folder is the workspace container; run project commands in the inner folder.
- Previous executable: `C:\Program Files\Godot\Godot.exe.exe` (machine-specific, not a project dependency).

## 2. Architecture and mandatory conventions

There are **four layers**. The discrete Simulation layer is now integrated into the playable turn loop.

| Layer | Location | Owns | Must not depend on |
|---|---|---|---|
| Data | `src/data/` | Definitions, catalogs, passive state, validation/copy helpers; future persistence schemas | Presentation or gameplay controllers |
| Simulation | `src/simulation/` | Pure RefCounted geometry, epidemic mathematics, and environmental responses | Logic, UI, Node2D, TileSet |
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
| `resources/abiotic_state.gd` | AbioticState | Field-wide temperature, humidity, light, pressure; `validate()`, `copy()` |
| `resources/float_range.gd` | FloatRange | Inclusive min/max interval; `validate()`, `copy()` |
| `resources/nutrient_rule.gd` | NutrientRule | Nutrient selector, optimal range, weight; `validate()`, `copy()` |
| `resources/abiotic_rule.gd` | AbioticRule | Factor selector, optimal range, weight; `validate()`, `copy()` |
| `resources/crop_data.gd` | CropData | Identity, growth ticks, base immunity, optional tolerance/requirement arrays; `validate()`, `copy()` |
| `resources/disease_data.gd` | DiseaseData | Rates, default algorithm, target crop, neighborhood, trigger arrays; `validate()`, `copy()` |
| `resources/transmission_modifier_profile.gd` | TransmissionModifierProfile | Optional temperature/humidity/N/K response parameters and caps; `validate()`, `copy()` |
| `resources/terrain_data.gd` | TerrainData | `is_plantable`, `allowed_crops`; `validate()`, `copy()` |
| `databases/crop_database.gd` | CropDatabase | `get_crop()`, `has_crop()`, `validate()` |
| `databases/disease_database.gd` | DiseaseDatabase | `get_disease()`, `get_diseases_for_crop()`, `validate()` |
| `databases/terrain_database.gd` | TerrainDatabase | `get_terrain()`, `has_terrain()`, `validate()` |
| `state/field_cell_state.gd` | FieldCellState | Passive per-cell state; `reset_crop_state()`, `is_mature(crop_data)`, `validate()`, `copy()` |
| `state/field_grid_state.gd` | FieldGridState | Row-major cell container, shared environment; `initialize()`, `is_in_bounds()`, `get_cell()`, `set_cell()`, `validate()`, `copy()` |

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
| `tools/run_tests.py` | Strict seven-test runner; rejects errors, warnings, failures, and missing PASS markers |
| `addons/test_harness/plugin.gd` | Environment-gated editor test harness using normal editor lifecycle |
| `src/logic/grid/field_grid_queries.gd` | FieldGridQueries: static `can_plant()`, `validate_terrain_assignments()` |
| `src/logic/farming/farming_controller.gd` | FarmingController: `initialize_field()`, `try_plant()`, `advance_growth()`, `seed_infection()`, `clear_crop()`, `process_simulation()`, `advance_simulated_turn()`, `get_grid_snapshot()`, `is_initialized()` |
| `src/logic/turns/turn_controller.gd` | TurnController: `advance_turn()`, `reset_clock()`, `try_set_algorithm_override()` |
| `src/presentation/world/terrain_tile_visual.gd` | TerrainTileVisual: terrain/source/atlas/alternative mapping entry |
| `src/presentation/world/terrain_tile_visual_map.gd` | TerrainTileVisualMap: `get_visual()`, `validate(tile_set)` |
| `src/presentation/world/field_world_view.gd` | FieldWorldView: `render_field()`, `render_grid()`, `refresh_crops()`, `frame_field()`, coordinate conversion, `_unhandled_input()` |
| `src/presentation/world/crop_debug_overlay.gd` | CropDebugOverlay: `show_snapshot()`, `get_cell_draw_position()`, `_draw()` |
| `src/presentation/world/field_prototype_presenter.gd` | FieldPrototypePresenter: composition root; connects UI intents to Logic and refreshes views |
| `src/presentation/ui/inspectors/tile_inspector_view.gd` | TileInspectorView: `display_cell()`, `clear_display()`, `validate_configuration()`, `close_requested`, `seed_infection_requested`, `set_seed_available()` |
| `tools/setup_disease_playtest.gd` | EditorScript: creates missing demonstration resources, validates existing ones, bakes controls, wires references, saves through Godot APIs |
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

Initial field: 9 × 6, three configurable uniform terrain bands. Intended permissions: dry soil supports sugarcane/corn; paddy mud supports rice; grass is unplantable and has null soil. Plantable cells require independent valid SoilState instances. Inspect the scene's exported `terrain_bands` for visual order rather than assuming enum order.

Planting is free on eligible empty cells. Next Turn advances discrete growth, capped at CropData.growth_ticks. Maturity is derived with `is_mature(crop_data)`. Epidemic progression runs after growth. Harvesting/rewards, treatments, and win/loss are not implemented. `clear_crop()` resets state without granting harvest rewards.

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

1. World converts mouse/touch viewport coordinates through the TileMapLayer transform and `local_to_map()`, then emits `cell_clicked(Vector2i)`.
2. Presenter starts in Inspect mode with no crop button selected. Selecting a crop enters Plant mode and closes the inspector. Clicking that selected crop again returns to Inspect mode.
3. Plant clicks call FarmingController.try_plant(). Inspect clicks retrieve a fresh detached grid snapshot and selected cell.
4. Farming signals `field_initialized`, `cell_changed(coordinates)`, or `planting_rejected(coordinates, reason)`; TurnController emits `turn_completed(turn_index)`.
5. Presenter refreshes crop visuals and an open inspector after relevant changes. Closing the inspector clears selection, preventing later turns from reopening it. Signal connections are guarded against duplicates.

`TileInspectorView.display_cell(cell_state: FieldCellState, crop_data: CropData)` accepts a **cell**, not FieldGridState. It displays terrain, pH/NPK, crop growth/maturity, optional active disease name, categorical state, removal outcome, and all five fraction percentages. Invalid values are flagged. DiseaseDatabase is optional; unresolved active IDs are shown explicitly. There is no separate crop-health scalar yet.

Overlay positioning uses TileMapLayer.map_to_local() with transforms into overlay space. Snapshot refresh queues redraw; valid fonts/fallback handling and mature-color markers are implemented.

## 6. Tile assets and resolved atlas issue

Temporary textures are under `assets/art/tilesets/terrain/`. Actual filenames currently have double extensions: `dry_soil.png.png`, `paddy_mud.png.png`, `grass.png.png`.

Current prototype settings: original images 3500 × 3500, import size limit 512, atlas texture region 512 × 512, isometric TileSet.tile_size `(276, 140)`, texture_origin `(4, -14)`. Re-measure if images, crop/padding, or import settings change; these are not universal dimensions.

| Terrain | Source ID in current visual map | Atlas coords | Alternative |
|---|---|---|---|
| DRY_SOIL | 0 | (0, 0) | 0 |
| GRASS | 1 | (0, 0) | 0 |
| PADDY_MUD | 2 | (0, 0) | 0 |

Each image is a separate atlas source. Never use `(0,1)` or `(0,2)` as terrain selectors. Source IDs are presentation-only and may change when reauthoring assets.

**Resolved:** the saved prototype previously contained stale `(0,1)` and `(0,2)` atlas properties. `tools/repair_terrain_atlas.gd` rebuilt its three single-tile sources through Godot APIs and serialized the scene, explicitly preserving main-scene UID `uid://beit4bfuaevfp`. Fresh strict tests now load without atlas errors. The user confirmed reloading the scene in the Editor. This was saved resource data, not test-runner cache; no routine cache deletion is needed.

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

Latest observed verification after interactive disease playtest setup: **seven tests pass, with zero engine warnings or errors**. This documentation refresh records that prior run; it does not claim a new code-test execution.

| Executable test | Coverage |
|---|---|
| `tests/logic/field_prototype_smoke.gd` | Core field, terrain, planting and turn behavior |
| `tests/logic/field_scene_integration.gd` | Native clicks, Inspect/Plant toggles, close_requested exactly once, live snapshots, preserved anchors/offsets |
| `tests/logic/disease_playtest_test.gd` | Fresh saved-scene load, external catalog wiring, native seed-button clicks, valid/invalid seeding, algorithm rollback, and spread |
| `tests/logic/simulation_scaffold_test.gd` | Reset/clear/replant, growth → simulation → UI ordering, pre-growth rejection |
| `tests/simulation/epidemiology_models_test.gd` | Fluxes, staging, conservation, seeded CA, switching, ambiguity, rollback |
| `tests/simulation/transmission_modifiers_test.gd` | Neutral responses, thresholds, caps/overflow, recipient effects, conservation and reproducibility |
| `tests/presentation/tile_inspector_builder_editor_test.gd` | Real builder, Undo/Redo, ownership, bindings, serialization and missing-HUD reconstruction |

Run from the inner project root:

```powershell
python tools/run_tests.py --godot 'C:\Program Files\Godot\Godot.exe.exe'
```

Replace the executable path on another device. Logs use absolute paths under `.godot`. Ensure project imports are complete and editor settings/log directories are writable.

**Do not launch the editor builder test with `--editor --script`.** A minimal custom SceneTree using that combination reproduced the editor window/dialog shutdown leaks on the tested Godot build. The runner now starts a normal headless editor with `GODOT_EDITOR_TEST=tile_inspector_builder`. The enabled `addons/test_harness` plugin runs only under that exact environment value; ordinary editor sessions do nothing. The separate `GODOT_PLAYTEST_SETUP=1` flag runs the explicitly requested persistent setup; the strict runner clears this flag from test subprocesses. The test is an async RefCounted helper, and the plugin releases it before normal editor-tree shutdown.

Temporary scene instances are freed; undo references are cleared before freeing detached HUD nodes; selection is cleared and deferred updates finish before exit. Grids own cells, cells do not point back to grids, and neighborhood arrays are local. No RefCounted ownership cycle was found. No leak diagnostics are suppressed. See [TESTING.md](TESTING.md).

Transfer checklist:

- Copy the full project, including project.godot, addons, source, `.gd.uid` sidecars, authored scenes/resources, original assets, import settings, tools, tests, and docs.
- Preserve relative paths and filename case. `.godot` is normally regenerated, but the current scene contains direct imported `.ctex` paths: verify those resolve after importing the original images. Prefer reassigning source textures in the Editor if regeneration leaves broken references.
- Open/import the project and let script class registration finish before playtesting.
- Open the prototype, verify catalogs/visual mappings, run the UI baker only if needed, save, and play with F6.
- Confirm dry-soil and rice permissions, grass rejection, maturity cap, Inspect/Plant toggling, inspector refresh, and close behavior.
- No Git repository was detected during an earlier implementation session; current repository status was not rechecked for this documentation update. Do not assume changes were committed or a remote backup exists.

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
- `FarmingController.advance_simulated_turn()` validates before growth and rolls back growth on simulation failure. Successful order is **growth → epidemic evaluation/commit → turn increment → turn_completed → UI snapshot**.
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

1. Select Rice and plant adjacent paddy-mud tiles.
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
- Crop overlay markers still indicate growth/maturity, not disease intensity. Read disease fractions in the inspector. Stochastic spread is not guaranteed on any individual turn.

`tools/setup_disease_playtest.gd` can be run from the Script Editor with Ctrl+Shift+X. It creates missing resources and validates existing ones without overwriting them; rerun verification confirmed both resource files remained byte-for-byte unchanged. The general baker reuses existing compatible nodes. Setup wires references and saves via Godot APIs, without raw scene/resource text. Headless saves disable thumbnail generation. Loaded non-tool Resource placeholders are validated using transient script instances.

The environment-gated editor harness also supports automated setup using `GODOT_PLAYTEST_SETUP=1`. Unlike tests, setup intentionally saves resources and the scene. Do not combine setup and test flags. New resources are not covered by editor Undo; the baker's node/ownership operations retain Undo/Redo support.

See [DISEASE_PLAYTEST.md](DISEASE_PLAYTEST.md) for operational instructions. Fresh-process verification covers native button input, saved references/ownership, all algorithm modes, wrong-host/repeat rejection, rollback, and spread. All seven strict tests are green with no resource leaks.

### Next work: propose and approve before implementation

1. Playtest the saved Rice Blast setup, calibrate its parameters using documented sources, and author the remaining diseases/profiles. The catalog is already wired to both TurnController and the inspector.
2. Propose richer scenario initialization/reset and diagnostic UI for weather, modifiers, and caps. Patient-zero seeding and model selection already exist; do not duplicate them.
3. Specify benchmark protocols: shared initial state and inputs, time step/horizon, seeded repeated runs, grid scales, timings/memory, and separation of rendering from numerical work. No mobile benchmark results or calibrated accuracy claims exist yet.
4. Define metrics, research provenance, SaveData and benchmark schemas, and catalog completeness requirements.
5. Propose harvesting/rewards, treatments, win/loss, broader soil/abiotic interactions, or base-immunity integration as separate approved increments.

Phase numbering shifted in older prompts. Confirm the next step title with the user; do not describe SIR/SEIR/CA or the approved environmental modifiers as pending implementation.

## 10. Coding, assets, and change discipline

Use snake_case files/methods/properties, PascalCase class names, UPPER_SNAKE_CASE enum members/constants, explicit return types, small components, and descriptive signals. Keep validation diagnostics index-prefixed for catalog entries. Treat shared definition Resources as read-only at runtime and use copies for mutable per-tile state/snapshots.

Reserved/planned locations: `src/logic/autoloads/` for a future typed signal bus if needed; `assets/art/models_3d/blender_source/` for possible Blender sources or prerendered meshes. These are approved organizational destinations, not implemented 3D gameplay or singleton systems. Current temporary art lives under `assets/art/tilesets/terrain/`.

Adopt conventional commits when version control is initialized: `feat(ui): bake persistent inspector controls`, `fix(world): validate atlas source coordinates`, `refactor(simulation): separate neighborhood geometry`, `test(logic): cover terrain planting rules`, `docs: update project handoff`. Use `type(scope): concise imperative description`, document behavior and relevant verification, and avoid claiming unrun tests or calibrated research results.

For the next assistant: read this handoff and current scripts first, follow PCI for new work, keep the four-layer boundary, and continue from the completed Phase 3 models/modifiers and seven-test green checkpoint. Do not rebuild the inspector, restore runtime UI layout overrides, or bypass the normal editor test lifecycle.
