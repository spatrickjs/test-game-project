# Running the strict test suite

From the project root:

```powershell
python tools/run_tests.py --godot 'C:\Program Files\Godot\Godot.exe.exe'
```

Use your installed executable path. Logs are written to absolute paths under
`.godot`. The runner requires a PASS marker and exit code zero, and rejects
every ERROR, WARNING, or failed assertion. No leak messages are filtered out.

## Editor lifecycle and teardown

Do not run the editor builder test with `--editor --script`. On the tested
Godot 4.7.2 build, even a minimal custom SceneTree launched this way leaked
editor windows/dialogs and their rendering resources at shutdown.

The runner instead sets `GODOT_EDITOR_TEST=tile_inspector_builder` for a normal
headless editor process. The enabled `addons/test_harness` plugin only runs
the test under that exact environment value; ordinary editor sessions do
nothing. The test is an async RefCounted helper using the real editor tree.
The plugin releases the helper and quits that tree through normal teardown.
Tests still exercise the real builder, Undo/Redo, bindings, ownership, scene
round trips, and missing-HUD reconstruction. No test scene changes are saved.

Round-trip scene instances are explicitly freed. Undo history is cleared before
freeing the detached original HUD. Editor selection/inspection is cleared and
deferred updates are given frames to finish before shutdown. The edited scene
remains editor-owned and is released by normal editor shutdown.

Runtime tests free their controller nodes or queue-free their scene and await a
frame. FieldGridState owns cells and AbioticState; FieldCellState owns SoilState,
with no references back to the grid. Simulation neighbor arrays are local and
the scaffold retains no cells or grids, so no RefCounted ownership cycle was
found. Temporary print_orphan_nodes diagnostics were removed after tracing the
editor-owned objects; indiscriminate freeing of engine orphan nodes is avoided.

Verified after interactive disease setup: all seven executable tests pass, with no engine errors,
warnings, atlas errors, or leak diagnostics. The inspector fixture is a helper,
not an executable test.
