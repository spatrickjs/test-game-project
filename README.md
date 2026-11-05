# Crop Field Game — Thesis Prototype

A turn-based, 2D isometric farming game built in **Godot with typed GDScript**. The thesis explores crop disease education and compares simulation approaches within a playable field. Android is the target platform; mouse controls support PC development and testing.

Players manage sugarcane, rice, and corn: plant, inspect, move, remove, water, fertilize, and harvest crops. **Next Turn** advances weather, soil moisture, crop growth, and the simulation. Soil conditions affect crop vitality and harvest quality. Camera zoom, panning, and an overview reset support navigating the field.

This is a research prototype. Game parameters are demonstration settings, not validated agricultural predictions. Inventory/currency rewards, save/load, complete disease content, and formal benchmarking remain unfinished.

## Start here

1. Import [project.godot](project.godot) in Godot. The last tested engine is **4.7.2**; the project uses the Mobile renderer and D3D12 on Windows.
2. Let Godot finish importing assets, then open [field_prototype.tscn](field_prototype.tscn), the main scene.
3. Press **F6** to run this scene or **F5** to run the project. No setup scripts are required for a normal launch.
4. Read [PROJECT_HANDOFF.md](docs/PROJECT_HANDOFF.md) for the latest checkpoint, known issues, and development decisions.

The default field is 9 × 6 tiles. Dry soil supports sugarcane/corn, paddy mud supports rice, and grass is unplantable. Check the scene's exported terrain bands for their actual order.

The terrain is generated from field data at runtime. `World/TerrainPreview` provides an editor-only preview, so individual terrain cells do not need to be hand-painted. Most tuning and node references are exposed in the **Inspector** using `@export`.

## Architecture: four layers

| Layer | Folder | Responsibility |
|---|---|---|
| Data | [`src/data/`](src/data/) | Definitions, Inspector resources, catalogs, and passive runtime state. |
| Simulation | [`src/simulation/`](src/simulation/) | Model calculations and grid mathematics, independent of HUD and rendering. |
| Logic | [`src/logic/`](src/logic/) | Gameplay rules, actions, authoritative field state, and turn coordination. |
| Presentation | [`src/presentation/`](src/presentation/) | Tile rendering, camera, input, HUD, and displaying state snapshots. |

**Ownership matters:** `FarmingController` owns the playable grid. Presentation receives detached snapshots and sends action requests; it does not directly edit authoritative cells. Data objects describe state, while models calculate outcomes and controllers coordinate updates.

A typical interaction follows this path:

```text
Touch/mouse input → FieldWorldView → FieldPrototypePresenter
                                         ↓
                                  FarmingController
                                         ↓
                                  detached snapshot
                                         ↓
                               World rendering + inspector
```

For **Next Turn**, the presenter routes the button to `TurnController`. The turn validates input, updates weather/moisture, evaluates crop growth, processes the simulation, and commits the clock. Failed processing rolls back the staged field changes. These updates happen on turns, not every rendered frame.

## Folder map

```text
project.godot                 Engine settings and main-scene reference
field_prototype.tscn          Main scene: controllers, world, camera, and HUD
src/
  data/
    enums/                   Shared identifiers
    resources/               Resource classes and authored definitions
    databases/               Catalog classes and saved catalogs
    state/                   Runtime grid/cell state and action results
  simulation/
    grid/                    Neighborhood geometry
    models/                  Simulation, crop-growth, and moisture calculations
    simulation_controller.gd Model coordination
  logic/
    farming/                 Crop actions and soil tools
    turns/                   Turn clock and advancement
    environment/             Inspector-configurable weather manager
    grid/                    Planting and terrain queries
  presentation/
    world/                   Field rendering, camera/input, presenter, preview
    ui/                      HUD helpers and tile inspector
assets/art/tilesets/
  terrain/                   Base terrain artwork
  foliage/                   Grass decoration artwork
  crops/                     Crop artwork and normalized runtime textures
  crops_raw/                 Source animation frames used by the visual setup tool
 tests/                      Logic, Simulation, and Presentation regressions
 tools/                      Test runner and editor setup/asset utilities
 addons/test_harness/        Editor plugin for automated editor tests/setup
 docs/                       Feature guides, testing instructions, and handoff
 .godot/                     Generated imports/cache and local test logs
```

`.gd` files contain scripts; `.tscn` files store scenes; `.tres`/`.res` files store Godot resources. A script such as `crop_data.gd` defines the fields, while `rice_data.tres` supplies values for one crop. Keep Godot `.uid` files with their scripts to preserve references. `.godot/` is generated working data, not gameplay source.

## Key files and what they contain

### Data: definitions and state

Paths in this table are relative to `src/data/`.

| File(s) | Purpose |
|---|---|
| `enums/simulation_enums.gd` | Shared crop, terrain, disease, algorithm, and state identifiers. |
| `resources/crop_data.gd`, `terrain_data.gd`, `disease_data.gd` | Definition schemas for crops, terrain permissions, and simulation configuration. |
| `resources/crop_growth_profile.gd` | Inspector settings for crop growth, vitality, and quality responses to soil conditions. |
| `resources/soil_state.gd` | Per-cell nutrients, pH, and moisture. |
| `resources/abiotic_state.gd` | Field-wide environmental state. |
| `resources/float_range.gd`, `nutrient_rule.gd`, `abiotic_rule.gd`, `transmission_modifier_profile.gd` | Reusable configuration and validation resources. |
| `resources/*_data.tres` | Authored sugarcane/rice/corn and dry-soil/paddy-mud/grass definitions. |
| `resources/diseases/rice_blast.tres` | Saved demonstration disease definition. |
| `databases/*_database.gd` | Catalog lookup and validation classes. |
| `databases/*.tres` | Saved crop, terrain, and default disease catalogs. |
| `state/field_cell_state.gd` | One tile's coordinates, soil, crop growth/vitality/quality, and simulation state. |
| `state/field_grid_state.gd` | Grid dimensions, cell storage, environment, validation, and copying. There is no `FieldGrid.gd` file. |
| `state/harvest_result.gd` | Harvest success/failure and collected crop quality information. |

Resources commonly expose `validate()` and `copy()`. Shared definitions should remain read-only during play; runtime state is copied when staging changes or providing snapshots.

### Simulation: where the algorithms live

These files implement the existing educational simulation. This map describes their software responsibilities; tuning and research validation are separate work.

| File | Purpose |
|---|---|
| [`simulation_controller.gd`](src/simulation/simulation_controller.gd) | Validates and coordinates model evaluation for a simulation turn. |
| [`spatial_sir_model.gd`](src/simulation/models/spatial_sir_model.gd) | Spatial SIR model using continuous compartment fractions. |
| [`spatial_seir_model.gd`](src/simulation/models/spatial_seir_model.gd) | Spatial SEIR model, including an exposed compartment. |
| [`stochastic_ca_sir_model.gd`](src/simulation/models/stochastic_ca_sir_model.gd) | Stochastic cellular-automaton SIR model using discrete cell states. |
| [`compartment_math.gd`](src/simulation/models/compartment_math.gd) | Shared numerical/state bookkeeping helpers for the models. |
| [`transmission_modifiers.gd`](src/simulation/models/transmission_modifiers.gd) | Existing model modifier calculations. |
| [`grid_neighborhood.gd`](src/simulation/grid/grid_neighborhood.gd) | Grid-neighbor selection and distance helpers. |
| [`crop_growth_model.gd`](src/simulation/models/crop_growth_model.gd) | Soil-dependent crop progression, vitality, and harvest-quality calculations. |
| [`soil_moisture_model.gd`](src/simulation/models/soil_moisture_model.gd) | Bounded moisture updates from rainfall and evaporation. |

### Logic: actions and turn flow

| File | Purpose |
|---|---|
| [`farming_controller.gd`](src/logic/farming/farming_controller.gd) | Initializes/owns the grid; handles planting, removal, transfer, harvest, soil additions, growth, and snapshots. |
| [`turn_controller.gd`](src/logic/turns/turn_controller.gd) | Owns the turn counter and coordinates Next Turn and algorithm selection. |
| [`weather_manager.gd`](src/logic/environment/weather_manager.gd) | Inspector-adjustable turn weather and moisture updates, plus committed-turn diagnostics. External climate loading is a future hook. |
| [`soil_tool_controller.gd`](src/logic/farming/soil_tool_controller.gd) | Configurable watering and fertilizer amounts; routes changes through FarmingController. |
| [`field_grid_queries.gd`](src/logic/grid/field_grid_queries.gd) | Planting eligibility and terrain-assignment checks. |

### Presentation: what players see and touch

Paths below are relative to `src/presentation/`.

| File(s) | Purpose |
|---|---|
| `world/field_prototype_presenter.gd` | Connects scene references/signals, selects tools, routes user actions, and refreshes the HUD/world. Start here to trace a button. |
| `world/field_world_view.gd` | Draws terrain/crop stages and optional grass decoration; converts clicks to cells; handles zoom, pan, and tap/drag/UI guardrails. |
| `world/field_terrain_preview.gd` | `@tool` terrain preview in the editor; does not run gameplay. |
| `world/terrain_tile_visual.gd`, `terrain_tile_visual_map.gd`, `TerrainTileVisualMap.tres` | Map logical terrain types to visual TileSet sources and atlas coordinates. |
| `world/crop_debug_overlay.gd` | Optional diagnostic drawing over crops. |
| `ui/inspectors/tile_inspector_view.gd` | Displays the selected tile and emits inspector action requests. |
| `ui/camera_zoom_button.gd` | Safe-area positioning helper used by standalone HUD buttons. Zoom behavior lives in FieldWorldView. |
| `ui/inspectors/build_tile_inspector_scene.gd` | Compatibility entry point for the editor HUD baker. |

## Where should I make a change?

| Task | Start here |
|---|---|
| Change field dimensions or terrain bands | FarmingController Inspector on the main scene. |
| Change crop definitions or allowed terrain | Crop/terrain `.tres` resources and their catalogs. |
| Change watering, fertilizer, or weather settings | SoilToolController / WeatherManager Inspector. |
| Change crop growth calculations | `crop_growth_model.gd`; settings in `crop_growth_profile.gd`. |
| Find SIR, SEIR, or CA implementation | `src/simulation/models/` and `simulation_controller.gd`. |
| Fix input, camera, or tile rendering | `field_world_view.gd`. |
| Add/change an action button | Presenter, the relevant Logic controller, and the saved HUD. |
| Change tile information shown to players | `tile_inspector_view.gd`. |
| Investigate a regression | Matching file in `tests/`, then its `.godot/*.log`. |

## Tools and tests

| File | Purpose |
|---|---|
| [`tools/run_tests.py`](tools/run_tests.py) | Runs the sixteen registered tests in fresh Godot processes. |
| `tools/bake_ui_to_scene.gd` | Builds persistent HUD/inspector controls through editor APIs. |
| `tools/setup_field_tools.gd` | Wires field tools, weather/soil services, and terrain preview into the scene. |
| `tools/setup_crop_growth_visuals.gd` | Builds/saves crop animation textures and atlas references. |
| `tools/crop_texture_normalizer.gd` | Frame-aware crop sizing, stage scaling, and stem anchoring. |
| `tools/setup_disease_playtest.gd` | Editor setup for the saved demonstration scenario. |
| `tools/repair_terrain_atlas.gd` | Historical one-time terrain repair utility; not a routine startup step. |
| `addons/test_harness/plugin.gd` | Runs editor tests/setup only when the appropriate environment flag is set. |

Setup tools **can save scene/resources**. Do not run them just to launch the game or tests. Scene/resource changes should use Godot Editor APIs and serialization rather than manually patching `.tscn`/`.tres` text.

Run tests from the project root with Python and your installed Godot executable:

```powershell
python tools/run_tests.py --godot "C:\Path\To\Godot.exe"
```

Tests are grouped into `tests/logic/`, `tests/simulation/`, and `tests/presentation/`. `inspector_test_fixture.gd` is a helper, not a standalone test. The runner requires a successful exit and PASS marker, and rejects engine errors, warnings, and failed assertions. See [TESTING.md](docs/TESTING.md) for editor lifecycle details; use the handoff for current results.

**Latest recorded status — November 6, 2026:** the duplicate `render_grid()` in FieldWorldView was repaired, and the new grass-overlay test passes. The previous full fifteen-test run still failed on grass-atlas errors and twelve crop-animation speed mismatches. The sixteen-test suite has not yet been verified green. See [handoff section 15](docs/PROJECT_HANDOFF.md#15-november-6-fieldworldview-repair-and-current-blockers) before changing related assets. Android device checks also remain outstanding.

## Team workflow and further reading

For new features, follow the project's **PCI workflow**: propose the touched layers/files, behavior, edge cases, and tests; obtain approval; then implement. Keep calculations out of UI scripts, preserve typed GDScript and shared enum IDs, and test changes at the relevant layer. Avoid committing generated `.godot/` cache/log files.

- [Project handoff](docs/PROJECT_HANDOFF.md): current checkpoint, architecture contracts, known issues, and next work.
- [Crop visuals](docs/STEP_4_1_CROP_VISUALS.md): stage artwork and normalization context.
- [Field tools](docs/STEP_4_2_FIELD_TOOLS.md): removal and transfer behavior.
- [Camera UX](docs/STEP_4_3_CAMERA_UX.md): mobile/PC input and camera boundaries.
- [Crop lifecycle](docs/STEP_4_4_CROP_LIFECYCLE.md): growth, vitality, quality, and harvest.
- [Weather and soil tools](docs/WEATHER_AND_SOIL_TOOLS.md): Inspector settings and turn integration.
- [HUD setup](docs/BAKE_UI_SETUP.md): persistent editor-built UI.

Older feature guides record historical checkpoints. When their test counts or status differ, use the dated project handoff as the current reference.
