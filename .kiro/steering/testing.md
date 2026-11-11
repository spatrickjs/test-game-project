---
inclusion: fileMatch
fileMatchPattern: "tests/**"
---
# Testing

- Tests are headless `extends SceneTree` scripts. Run via `tools/run_tests.py --godot <path>`.
- Pass = prints a `*_PASS` marker and `quit(0)`. Fail = `printerr("FAIL: ...")` and `quit(1)`.
- Use `_check(condition, label)` collecting into `_failures`; report all at end.
- Async tests: `_initialize` -> `_run.call_deferred()`, `await process_frame`.
- Scene tests: `load("res://field_prototype.tscn")`, `GameplayFixture.prepare` then `.start`. Drive input via `root.push_input`. Advance farmer with `QueueDriver.finish`.
- Never save scenes or resources. Temp output only under `user://` or `res://.godot/`.
- Menu property tests: `PropertyTestRunner.run_property` (>=100 iterations), traceability tag comment above each call.
- Editor tests run through the gated plugin, not `--editor --script`.
- Seed all RNG. Assert determinism and rollback (state, RNG, clock) on failure paths.
- New logic needs: success, rejection-without-mutation, and boundary cases.

## Runner pass criteria

`run_tests.py` requires exit 0 + `_PASS` marker + **no** `ERROR:`, `WARNING:`, or `FAIL:` lines.  
Pre-existing `ERROR: Cannot create tile…` lines appear in every scene-loading test (terrain/foliage atlas init) and are not regressions. When these are present, verify results by checking the `_PASS` marker directly rather than relying solely on the runner exit code.

## Test execution timing

Run tests **once as a final verification phase after all tasks are complete**. Do not run after each individual task. Earlier runs are allowed only to debug a concrete failure. After a final-phase failure, fix and rerun affected checks; repeat the full suite only when needed.

## Test selection

| Changed | Run |
|---|---|
| `src/simulation/` | `tests/simulation/*` |
| `src/logic/farming`, `turns` | `tests/logic/*` |
| `src/presentation/world`, `ui` | `tests/presentation/*`, `tests/logic/field_scene_integration.gd` |
| `src/logic/menu`, `presentation/menu` | `tests/menu/*` |
| `src/logic/grid/field_grid_queries.gd` | `tests/simulation/fence_connections_test.gd`, `tests/logic/*` |
