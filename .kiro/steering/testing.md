---
inclusion: fileMatch
fileMatchPattern: "tests/**"
---
# Testing

- Tests are headless `extends SceneTree` scripts. Run: `godot --headless --script res://tests/<area>/<file>.gd` (confirm exact flags in project).
- Pass = prints a `*_PASS` marker and `quit(0)`. Fail = `printerr("FAIL: ...")` and `quit(1)`.
- Use `_check(condition, label)` collecting into `_failures`; report all at end.
- Async tests: `_initialize` -> `_run.call_deferred()`, `await process_frame`.
- Scene tests: `load("res://field_prototype.tscn")`, `GameplayFixture.prepare` then `.start`. Drive input via `root.push_input`. Advance farmer with `QueueDriver.finish`.
- Never save scenes or resources. Temp output only under `user://` or `res://.godot/`.
- Menu property tests: `PropertyTestRunner.run_property` (>=100 iterations), traceability tag comment above each call.
- Editor tests run through the gated plugin, not `--editor --script`.
- Seed all RNG. Assert determinism and rollback (state, RNG, clock) on failure paths.
- New logic needs: success, rejection-without-mutation, and boundary cases.

| Changed | Run |
|---|---|
| `src/simulation/` | `tests/simulation/*` |
| `src/logic/farming`, `turns` | `tests/logic/*` |
| `src/presentation/world`, `ui` | `tests/presentation/*`, `tests/logic/field_scene_integration.gd` |
| `src/logic/menu`, `presentation/menu` | `tests/menu/*` |
