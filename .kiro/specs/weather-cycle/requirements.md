# Weather Cycle Requirements

Status: proposed specification, prepared November 10, 2026.

Target repository: https://github.com/spatrickjs/test-game-project

Suggested location: `.kiro/specs/weather-cycle/requirements.md`.

## Purpose and baseline

As a player, I want weather to change as I advance turns so that rainfall and evaporation influence how I manage crops.

The repository already implements Inspector-configured weather, deterministic sine fluctuations, moisture updates, and transactional turn processing. This specification formalizes that behavior and directs verification and gap fixes; it does not propose replacing the existing weather system. The accompanying `weather_cycle.feature` is the acceptance reference and belongs in `features/`.

## Scope

Included: turn-driven cycles, configurable rainfall and temperature, evaporation response, soil moisture, crop-growth ordering, validation, rollback, diagnostics, and regression coverage.

Excluded: named sunny/rainy/storm states, seasonal calendars, random forecasts, weather animations or audio, new weather HUD, save/load, external climate parsing, and changes to disease formulas. Climate resource and CSV options remain unsupported hooks. Values represent gameplay parameters, not calibrated agricultural predictions.

## Definitions

- Turn index: number of completed turns; weather uses this zero-based value before the next turn commits.
- Cycle phase: `turn_index modulo cycle_length_turns`.
- Successful turn: all required stages validate and commit; the clock then advances once.
- Soil tile: any cell containing a soil state, whether planted or empty.
- Weather disabled: bypass hydration changes. Fluctuations disabled: continue applying baseline weather.

## Requirements and acceptance criteria

### R1 — Advance weather only with game turns

1. WHEN a permitted Next Turn request succeeds, the system SHALL evaluate weather once with the pre-commit turn index and increment the clock once.
2. WHILE no turn is requested, weather SHALL NOT change moisture or phase because time or rendering frames pass.
3. WHEN the game state, turn limit, pending field actions, or turn-in-progress guard rejects a request, weather SHALL NOT consume a phase or commit field changes.
4. WHEN a new session initializes its clock to zero, its first weather evaluation SHALL use phase zero. Weather SHALL have no independent timer or mutable phase counter.

### R2 — Generate a deterministic repeating cycle

1. WHEN fluctuations are enabled, weather SHALL use `sin(2*pi*(t modulo L)/L)` to vary baseline temperature and rainfall by their respective amplitudes.
2. WITH identical settings, evaluations at indices `t` and `t + L` SHALL produce equal temperature, rainfall, and evaporation within an absolute tolerance of `0.000001`.
3. WHEN fluctuations are disabled, weather SHALL use baseline values even when amplitudes are nonzero.
4. WHEN cycle length is one, every evaluation SHALL use baseline weather within that tolerance.
5. Cycle repetition SHALL apply to weather inputs, not imply that accumulated soil moisture returns to its original value.

### R3 — Apply bounded moisture changes

1. Weather SHALL clamp calculated rainfall to `[0, 1]`.
2. Weather SHALL calculate evaporation using the baseline evaporation multiplied by independently bounded temperature and humidity response factors, as defined in `design.md`.
3. Weather SHALL update every soil tile using `clamp(old moisture + rainfall * rainfall scale - evaporation, 0, 1)`.
4. Weather SHALL skip cells without soil and SHALL NOT create soil for grass cells.
5. With default settings and fluctuations disabled, rainfall and evaporation SHALL balance and preserve moisture.
6. Weather SHALL NOT directly change nutrients, pH, crop payloads, or the field's shared abiotic temperature and humidity. Subsequent growth and simulation stages may perform their existing updates.

### R4 — Integrate with growth and preserve turn atomicity

1. Weather SHALL update the staged field before crop growth evaluates moisture for that same turn.
2. Only FarmingController SHALL commit the authoritative field; presentation SHALL receive detached snapshots.
3. IF any stage fails, the system SHALL discard staged field changes, preserve the turn index, restore simulation RNG and diagnostic counters changed during the attempt, and avoid committing disease activation state.
4. A retry after failure SHALL evaluate the same weather phase unless configuration has explicitly changed.
5. Failed processing SHALL NOT emit `turn_completed` or publish a new successful weather summary.

### R5 — Support configuration and disabled weather

1. Weather SHALL retain the existing exported Inspector properties and defaults listed in `design.md`.
2. WHEN a valid configuration changes during play, it SHALL affect the next attempted turn; it SHALL NOT immediately mutate the field. Its field effects become visible only if that turn succeeds.
3. WHEN weather is disabled, its configuration validation SHALL be bypassed, while grid and turn-index validation SHALL still apply. An otherwise valid turn SHALL continue without weather moisture changes.
4. Disabled weather SHALL NOT pause the global turn clock. Re-enabling weather SHALL use the current clock phase.

### R6 — Reject invalid inputs safely

1. Enabled weather SHALL reject nonpositive cycle lengths, unsupported source modes, invalid numeric configuration, reversed evaporation factor bounds, and fluctuations crossing absolute zero.
2. Numeric validation SHALL follow the runtime constraints in `design.md`; Inspector slider limits SHALL NOT substitute for runtime validation.
3. Weather SHALL reject a missing or invalid grid, a negative turn index, non-finite calculated factors, or invalid calculated moisture.
4. Rejection SHALL provide a useful diagnostic identifying the problem and SHALL leave authoritative field state and the clock unchanged.
5. Selecting CLIMATE_RESOURCE or CSV while enabled SHALL explicitly report that external sources are not implemented; no external data SHALL be silently loaded or ignored.

### R7 — Report committed outcomes

1. After a successful field commit, WeatherManager SHALL record a summary with the completed-turn number, changed soil tile count, total soil tile count, and before/after mean moisture.
2. Disabled weather and zero net moisture change SHALL be distinguished in the summary.
3. Console output SHALL respect `debug_moisture_updates`; recording the summary SHALL remain available when console output is disabled.
4. Failure SHALL preserve the previously committed summary; a stale summary SHALL NOT be interpreted as success for the failed attempt.

### R8 — Verify acceptance coverage

1. Every scenario and example row in `features/weather_cycle.feature` SHALL map to an automated Godot test or an explicitly recorded verification gap.
2. Tests SHALL use controlled fixtures and an absolute numeric tolerance of `0.000001` for calculated weather values.
3. Coverage SHALL include the existing feature scenarios plus the additional boundary contracts in R1, R5, R6, and R7.
4. Verification SHALL use the repository's existing Godot test harness. Gherkin remains an acceptance specification unless a separate executable step-binding runner is deliberately introduced.
5. Results SHALL distinguish weather failures from unrelated baseline failures. Existing code or test presence SHALL NOT be reported as a passing execution result.

## Acceptance traceability

| Gherkin scenario | Requirements |
|---|---|
| Balanced default weather preserves soil moisture | R3, R5 |
| Weather waits for the player to advance a turn | R1 |
| Weather follows a deterministic repeating cycle | R1, R2, R3 |
| Disabled fluctuations use baseline weather | R2, R5 |
| Rainfall remains within normalized bounds | R2, R3 |
| Rainfall and evaporation keep soil moisture within bounds | R3 |
| Warm and dry weather increases evaporation | R3 |
| Weather affects planted and empty soil tiles | R3 |
| Crop growth uses the moisture updated by weather | R4 |
| Hydration weather preserves the disease environment | R3 |
| Disabled weather allows the turn to complete without moisture updates | R5 |
| Runtime weather changes apply on the next successful turn | R5 |
| Invalid cycle lengths reject the turn without changing state | R6 |
| A one-turn cycle always uses baseline weather | R2 |
| Unsupported climate sources reject the turn | R6 |
| A failed turn does not consume a weather cycle phase | R1, R4, R7 |

R8 applies to all rows. Supplemental checks are identified in `tasks.md`; add corresponding Gherkin scenarios when adopting those acceptance cases.

## Sources

- [Weather and soil tools](https://github.com/spatrickjs/test-game-project/blob/main/docs/WEATHER_AND_SOIL_TOOLS.md)
- [WeatherManager](https://github.com/spatrickjs/test-game-project/blob/main/src/logic/environment/weather_manager.gd)
- [TurnController](https://github.com/spatrickjs/test-game-project/blob/main/src/logic/turns/turn_controller.gd)
- [FarmingController](https://github.com/spatrickjs/test-game-project/blob/main/src/logic/farming/farming_controller.gd)

These references describe the reviewed baseline; record the exact implementation commit during task T1.
