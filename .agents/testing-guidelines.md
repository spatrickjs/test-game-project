# Testing and final verification

## Timing

Run tests **once as a final verification phase, after all implementation tasks are complete**. Write/update tests during implementation, but do not execute them after individual tasks. Earlier runs are allowed only when explicitly requested or necessary to debug a concrete problem. After a final-phase failure, fix it and rerun affected checks; repeat the full suite only when needed to establish the final result. Do not rerun already-passing checks without a reason.

This user-requested timing replaces `.kiro/steering/workflow.md`'s targeted-then-full sequence. A single full-suite run includes the affected-layer checks.

## Framework and commands

The project uses custom Godot tests, not GUT/GdUnit. `tools/run_tests.py` is the executable registry and authoritative launcher. Import the project/assets in the compatible Godot editor first. From the repository root, substituting the installed executable path:

```powershell
python tools/run_tests.py --godot 'C:\path\to\Godot.exe'
```

For permitted debugging or failure follow-up, `--test` accepts a registered path and is repeatable:

```powershell
python tools/run_tests.py --godot 'C:\path\to\Godot.exe' --test tests/logic/fence_treatment_test.gd
```

The runner launches fresh processes with a 60-second limit per test and logs under `.godot/`. Passing requires exit zero, an `_PASS` marker, and no `ERROR:`, `WARNING:`, or `FAIL:` diagnostics. Never suppress leak warnings to obtain a pass.

Editor tests run through the enabled `addons/test_harness` plugin and `GODOT_EDITOR_TEST`, selected by the runner. Do not launch them with `--editor --script`. See `docs/TESTING.md` for teardown rationale, not current test counts/results.

## Organization and authoring

- Use `tests/{logic,simulation,presentation,menu}/`. Existing names are `*_test.gd`, `*_property_test.gd`, and editor/runtime variants; preserve existing smoke/integration names.
- Runtime executables extend `SceneTree`; async cases defer `_run` from `_initialize` and await frames. Collect `_check` failures, print `FAIL:` messages or a suite-specific `*_PASS`, and quit with the corresponding status.
- Register new executables explicitly in `tools/run_tests.py`; helper scripts are not standalone tests. Editor cases are RefCounted helpers driven by the plugin; add any new editor dispatch deliberately.
- Cover success, rejection without mutation, boundaries, seeded determinism, and rollback where applicable. Menu properties use `tests/menu/property_test_runner.gd`, at least 100 iterations, and a feature/property traceability comment.
- Reuse `tests/logic/gameplay_test_fixture.gd` (`prepare` before adding the scene, then `start`) and `queued_action_test_driver.gd` (`finish`) for queued gameplay. Use `root.push_input` for input paths and the existing inspector fixture for inspector cases.
- Never save authored scenes/resources from tests. Redirect persistence to test-specific `user://` paths or `.godot/`; clean up fixtures, nodes, and temporary files.

## Completion evidence

Run the registered suite once for completed implementation. Add acceptance-focused interactive checks for changed visuals/input; headless success alone does not verify appearance or Android interaction. Report commands, outcomes, untested scenarios, and environmental blockers. Documentation-only changes need link/content review, not a game test run. Never present historical results as current verification.
