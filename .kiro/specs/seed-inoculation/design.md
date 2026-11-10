# Seed inoculation design

## Existing integration points

`FieldCellState` is passive runtime data with explicit `copy`, `validate`, and `reset_crop_state` methods. `FieldAction` carries detached queued intent. `FarmingController` owns queue validation, reservations, arrival, and transactions. Presentation consumes snapshots. `TransmissionModifiers.evaluate` already combines recipient weather/nutrient factors and applies overflow-safe caps for shared model callers.

## State and configuration

Introduce a validated `InoculationProfile` resource with duration, moisture bounds, pre-mature/mature bonuses, and weather decay configuration. User-approved defaults are defined in requirements.md. Reject nonfinite/out-of-range bonuses and moisture bounds, invalid durations, and negative decay. Weather decay interpolates dry/humid endpoints using the turn's relative humidity.

Add `inoculation_turns_remaining: int = 0` and `inoculation_bonus: float = 0.0` to `FieldCellState`. Active means both values are positive on a living occupied cell. Inactive state is canonically zero/zero. Extend copy, reset, and validation; inspect all manually copied crop payloads, especially crop transfer, to preserve these fields. Do not infer protection from UI state.

## Action transaction

Append INOCULATE to `SimulationEnums.FieldActionKind` without renumbering existing entries. Route presenter selection through the existing action queue. Extend the shared eligibility path with target, crop, moisture, and profile checks. Resolve growth stage using the project's existing growth model rather than UI label strings.

At farmer arrival, revalidate revision and eligibility, build a candidate state, set bonus and duration, validate the candidate, then commit once through the controller's existing mutation path. Return a structured failure reason through the existing feedback route. Repeated applications replace rather than add protection. Queue reservation and cancellation behavior follows existing farming tools.

## Simulation integration

Extend `TransmissionModifiers.evaluate` with an explicit recipient protection input defaulting to neutral for existing callers; pass it from each model's recipient cell snapshot. Expose the resulting protection factor on its result for diagnostics.

```text
protection_factor = 1 - active_bonus
effective_beta = capped_product(base_beta, weather, nutrient, protection_factor)
hazard = capped_product(effective_beta, pressure)
```

Include the protective factor before the existing cap calculation. Do not apply it again to infection probability or source infectiousness. Use existing SIR/SEIR/CA transition formulas and conservation checks.

For a successful turn, compute transmission using start-of-turn protection, then age each protected crop once in the candidate next state: subtract one remaining turn and the configured weather decay from its bonus, clamping at zero. Clear both fields if either expires. Publish only after the entire candidate turn validates. Use the same environmental snapshot as that turn's simulation; rendering and inspector refreshes never age state. A duration of 3 therefore protects exactly three transitions when decay does not end it sooner.

## Presentation

Wire Inoculate in `field_prototype.tscn` and the relevant toolbar setup/bake tools so regeneration preserves it. Add `TOOL_INOCULATE` handling to `FieldPrototypePresenter`, including eligibility and cursor selection. Reuse queue highlight and farmer behavior.

Extend inspector snapshot formatting and `tile_inspector_view.gd` with active status, turns, and bonus. Surface failed applications in the inspector even when no valid tile can be selected. Extend `crop_debug_overlay.gd` or its snapshot adapter with a small icon/aura gated by overlay visibility and active protection. Preserve existing crop artwork and input behavior.

## Verification

Use controller tests for application, rejection, reapplication, queue timing, stale requests, cancellation, and crop transfer/reset. Use deterministic simulation fixtures for matching treated/untreated recipients, SIR and SEIR, neutral CA behavior, caps, zero pressure, copy isolation, expiration boundaries, configured weather decay, and failed-turn rollback. Do not compare unrelated neighbors with different conditions or require a random outbreak to be smaller in every run.

Add scene integration checks for button bindings, cursor mode, inspector text, and overlay expiration. Verify saved scene and regenerated UI agree. Register executable tests with `tools/run_tests.py` and follow `docs/TESTING.md`; report baseline failures separately from regressions. Perform a rendered playtest for icon readability and inspector layout. Save/load persistence is not specified here; if runtime state serialization is encountered, include neutral defaults for older saves.
