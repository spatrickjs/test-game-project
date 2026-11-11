---
inclusion: fileMatch
fileMatchPattern: "tests/**"
---

# Testing

godot binary = /home/nnded/bin/Godot_v4.7-stable_mono_linux_x86_64/Godot_v4.7-stable_mono_linux.x86_64

## Conventions

- Tests are headless `extends SceneTree` scripts.
- Follow the project's prescribed test runner when available.
- Confirm the exact invocation and flags once before running tests.
- Pass = prints a `*_PASS` marker and `quit(0)`.
- Fail = `printerr("FAIL: ...")` and `quit(1)`.
- Use `_check(condition, label)` collecting into `_failures`; report all at end.
- Async tests: `_initialize` -> `_run.call_deferred()`, `await process_frame`.
- Scene tests: `load("res://field_prototype.tscn")`, `GameplayFixture.prepare` then `.start`. Drive input via `root.push_input`. Advance farmer with `QueueDriver.finish`.
- Never save scenes or resources. Temp output only under `user://` or `res://.godot/`.
- Menu property tests: `PropertyTestRunner.run_property` (>=100 iterations), traceability tag comment above each call.
- Editor tests run through the gated plugin, not `--editor --script`.
- Seed all RNG. Assert determinism and rollback (state, RNG, clock) on failure paths.
- New logic needs: success, rejection-without-mutation, and boundary cases.

## Test Execution

1. Identify the tests relevant to the changed layer.
2. Inspect the test runner and its failure criteria before execution.
3. Establish a baseline when necessary, particularly when existing failures could be mistaken for regressions.
4. Run the relevant tests after implementation.
5. Do not repeatedly run the same tests without a specific reason.
6. Run the full suite once before finishing.
7. If a test fails, inspect its output and investigate the cause before deciding whether another run is necessary.
8. Do not investigate or fix unrelated pre-existing failures.
9. Report environmental blockers and pre-existing failures separately from regressions.

## Test Selection

| Changed | Run |
|---|---|
| `src/simulation/` | `tests/simulation/*` |
| `src/logic/farming`, `turns` | `tests/logic/*` |
| `src/presentation/world`, `ui` | `tests/presentation/*`, `tests/logic/field_scene_integration.gd` |
| `src/logic/menu`, `presentation/menu` | `tests/menu/*` |
