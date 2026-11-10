# Repository findings

Verified by static inspection of [spatrickjs/test-game-project](https://github.com/spatrickjs/test-game-project/tree/51639d4336e2f9810b9ac0be89064055b7740995), `main` at `51639d4336e2f9810b9ac0be89064055b7740995`, on 2026-11-10. No game or tests were executed. Recheck affected facts when the checkout differs. Paths below are repository-relative.

## Entry points and directory map

- `project.godot`: Godot 4.7 feature level, Mobile renderer, D3D12 on Windows, 1280×720 viewport. README reports 4.7.2 as last tested; no installed engine was verified.
- Startup: `src/presentation/menu/main_menu.tscn`; its `game_scene` points to `field_prototype.tscn`.
- `field_prototype.tscn`: saved field is 9×9 with grass-only terrain bands. `FarmingController` defaults are 9×6 with mixed bands; scene exports override them.
- `src/`: layer responsibilities are in [.agents/architecture.md](.agents/architecture.md).
- `assets/art/tilesets/`: terrain, foliage, crop textures, and other world art; `crops_raw/` contains source frames, `crops/normalized/` contains runtime textures.
- `tools/`: test runner, UI baker, and editor setup utilities. `addons/test_harness/`: environment-gated editor entry points.
- `features/`: menu and fence Gherkin. `.kiro/specs/`: matching requirements/design/tasks. `.kiro/steering/`: pre-existing project guidance.
- `docs/`: feature setup guides and historical handoff. Test infrastructure is documented only in [.agents/testing-guidelines.md](.agents/testing-guidelines.md).

## Implementation lookup

| Concern | Start here / existing behavior |
|---|---|
| Field actions | `src/logic/farming/farming_controller.gd`: `enqueue_action`, `action_error`, `arrive_at_action`; reservations and revisions reject conflicting/stale requests. Move commits at delivery. |
| Turn orchestration | `src/logic/turns/turn_controller.gd`: `advance_turn`; field staging in `FarmingController.advance_simulated_turn`; clock advances after successful field commit. |
| Session outcomes | `src/logic/turns/game_state_manager.gd`: MENU/PLAYING/GAME_OVER/VICTORY; defaults are five successful harvests and twenty turns. |
| Simulation | `src/simulation/simulation_controller.gd`; `models/` contains SIR, SEIR, stochastic CA, growth, moisture, and transmission calculations; `grid/grid_neighborhood.gd` supplies geometry. |
| Runtime data | `src/data/state/field_grid_state.gd`, `field_cell_state.gd`, `field_action.gd`; resource classes in `src/data/resources/`, catalogs in `src/data/databases/`. |
| Disease introductions | `src/logic/environment/disease_activation_controller.gd`; `disease_activation_policy.gd` defaults: turn 3, chance 0.25, cooldown 3, limit 2, seed 2026. Saved policy allows all nine catalog IDs. |
| World/UI wiring | `src/presentation/world/field_prototype_presenter.gd`; `field_world_view.gd`, `farmer_agent.gd`, and `src/presentation/ui/inspectors/tile_inspector_view.gd`. |
| Menu/settings | `src/presentation/menu/main_menu_presenter.gd`; `src/logic/menu/` controllers. SettingsController persists working settings to `user://settings.cfg` and supports save/revert/dirty state. |
| Save gap | `SaveGameController` detects `user://savegame.dat` and reads metadata only. MainMenuPresenter routes New Game and Continue to the same `_start_game()`; restoration is not implemented there. |

## Drift and unresolved questions

- README's field-as-main-scene and 9×6 descriptions conflict with the saved configuration above. Use current configuration for actual behavior.
- `docs/TESTING.md` mentions seven tests; `docs/PROJECT_HANDOFF.md` mentions 21. The inspected runner registers 29. Neither historical pass/failure claims establish current suite health.
- `.kiro/steering/product.md` understates disease availability: the saved database contains nine entries and activation allows all nine. Draft status and fictional tuning remain relevant; see `docs/DISEASE_FINALIZATION.md`.
- `features/main_menu.feature` requires progress restoration, but the implementation above does not provide it. Resolve scope before treating Continue as complete.
- Fence tasks contain checked parent tasks with unchecked children. Task checkboxes are not proof of implementation, approval, or passing verification.
- No tracked GitHub Actions workflows, GUT/GdUnit dependency, or existing AGENTS.md was found in the complete tree. CI outside this repository and current runtime health are unknown.

Recommendation: reconcile older documentation when those areas are next changed; do not silently reinterpret unresolved requirements.
