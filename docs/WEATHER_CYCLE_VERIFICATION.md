# Weather cycle acceptance verification

Implementation baseline: clean checkout `fe5fcdf43cce2db37a957b4172866fe7b0558c69`.
Engine: `4.7.2.stable.official.ed1daf0bf`.
Verification status: final execution pending; source presence is not a pass result.

## Scope and change

The existing turn-indexed weather system is retained. WeatherManager now rejects non-finite evaporation before iterating soil cells, including on all-grass fields. Without that guard, finite but extreme factors could overflow and escape detection when no soil existed. No defaults, scenes, assets, disease formulas, or public interfaces changed.

The registered `tests/logic/weather_soil_tools_test.gd` invokes the supplemental helper `tests/logic/weather_cycle_checks.gd`. The helper is not a separate executable, so the runner still has 29 entries. All supplemental calculated-value assertions use absolute tolerance 0.000001. Existing baseline checks remain in the registered test.

## Scenario traceability

`checks` below means `tests/logic/weather_cycle_checks.gd`. `suite` means `tests/logic/weather_soil_tools_test.gd`. Every outline row is included in the indicated loop.

| Feature scenario | Automated evidence |
|---|---|
| Balanced default weather preserves soil moisture | suite `_run`: `Balanced defaults preserve moisture intentionally` and native completed-turn check |
| Weather waits for the player to advance a turn | suite `_run`: `Idle frames never advance weather` |
| Weather follows a deterministic repeating cycle | checks `_cycle_examples`: indices 0–5, separate rain-only and temperature-only cases |
| Disabled fluctuations use baseline weather | checks `_cycle_examples`: nonzero amplitudes with fluctuations off |
| Rainfall remains within normalized bounds | checks `_cycle_examples`: phase 3 lower bound and phase 1 upper bound; reduced rainfall scale distinguishes rainfall clamp from soil saturation |
| Rainfall and evaporation keep soil moisture within bounds | checks `_moisture_and_isolation`: four feature table rows |
| Warm and dry weather increases evaporation | checks `_moisture_and_isolation`: 0.4712 expected result |
| Weather affects planted and empty soil tiles | checks `_moisture_and_isolation`: empty dry soil, corn, rice, grass |
| Crop growth uses the moisture updated by weather | checks `_growth_order`: isolated profile distinguishes old moisture 0.5 from new 0.6; suite also retains dry-out ordering |
| Hydration weather preserves the disease environment | checks `_moisture_and_isolation`: complete non-moisture state comparison; suite shared ambient state check |
| Disabled weather allows the turn to complete without moisture updates | checks `_lifecycle_and_rollback`: two disabled turns preserve moisture and advance phase |
| Runtime weather changes apply on the next successful turn | checks `_lifecycle_and_rollback`: edit causes no mutation, then contributes once; suite runtime rates check |
| Invalid cycle lengths reject the turn without changing state | checks `_validation` and `_lifecycle_and_rollback`: lengths 0/-1, direct and full-turn rejection |
| A one-turn cycle always uses baseline weather | checks `_cycle_examples`: three consecutive evaluations |
| Unsupported climate sources reject the turn | checks `_validation` and `_lifecycle_and_rollback`: both resource and CSV, direct and full-turn rejection |
| A failed turn does not consume a weather cycle phase | checks `_lifecycle_and_rollback`: nonzero phase, mutation/consumed RNG, failed attempts, same-phase retry and one completion |
| Sequential turns accumulate moisture using each cycle phase | checks `_cycle_examples`: cumulative six-turn expectations |
| Re-enabling weather uses the current game turn | checks `_lifecycle_and_rollback`: phase three after two disabled turns |
| A new session resets the weather phase | checks `_lifecycle_and_rollback`: field/clock/activation reset, phase zero |
| Requests outside active gameplay do not advance weather | checks `_lifecycle_and_rollback`: menu and post-terminal rejection |
| A reentrant turn request cannot consume a second phase | checks `_lifecycle_and_rollback`: completion observer attempts nested request while playing |
| Fence work blocks turns until the queued action completes | suite `_run`: pending fence rejection compares complete field and clock |
| Weather follows the fence and soil lifecycle | suite `_run`: queued fence, remove, dig, neighboring soil and restored-soil update |
| Disabled weather bypasses configuration errors but not invalid inputs | checks `_validation`: disabled CSV/NaN/zero length succeeds only with valid grid/index |
| Invalid numeric weather settings cannot partially change the field | checks `_validation`: each normalized/nonnegative/temperature property, NaN/infinity, bounds and complete state comparison |
| Evaporation overflow is rejected even on a soil-free field | checks `_validation`: finite factors 1e200 overflow, no-soil and soil grids |
| A failed activation proposal does not commit weather or randomness | checks `_lifecycle_and_rollback`: real proposal followed by injected rejection, state preserved |
| Weather summaries describe committed outcomes | checks `_diagnostics`: counts, means, disabled/balanced/zero-soil cases; final log sections bracket silent and enabled output |
| The selected tile inspector refreshes after weather commits | suite `_run`: 65.0% then 60.0% after native Next Turn input |

Additional boundaries: independently capped temperature/humidity factors, raw-factor overflow, grid validation, unrelated crop/soil/environment preservation, and successful-turn notification behavior are covered by the same helper.

## Execution procedure

Follow `.agents/testing-guidelines.md`: one final registered-suite run after implementation. No preliminary baseline test run was made; failures cannot automatically be called pre-existing without separate evidence.

```powershell
& 'C:\Users\glenr\AppData\Local\Python\pythoncore-3.14-64\python.exe' tools/run_tests.py --godot 'C:\Program Files\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
```

After a final-phase failure, use the same command with `--test tests/logic/weather_soil_tools_test.gd` for affected-check follow-up. Do not repeat already-passing tests without cause.

Inspect `.godot/weather_soil_tools_test.log`: no `Weather turn` line may occur between `WEATHER_SILENT_BEGIN` and `WEATHER_SILENT_END`; exactly one is expected between `WEATHER_DEBUG_BEGIN` and `WEATHER_DEBUG_END`. The runner additionally requires exit zero, `_PASS`, and no error/warning/failure diagnostics.

## Limits

Gherkin defines acceptance behavior; Godot assertions implement the checks. There is no direct Gherkin runner or step binding. Native input and inspector text checks do not certify visual appearance or physical Android behavior. No appearance/input behavior was changed by this work; physical Android touch/performance remains unverified.
