# Step 4.4: crop lifecycle and harvest

Implemented with user approval on 2026-11-05 (Asia/Shanghai). All numeric defaults are fictional game tuning, not agronomic recommendations. This system affects growth, vitality and harvest quality only; disease equations and parameters are unchanged.

## State and configuration

- `SoilState.moisture`: normalized per-cell water availability, default 0.5; independent of field-wide relative humidity. Validation rejects invalid/non-finite input and copying preserves it.
- `CropData.growth_profile`: a separate `CropGrowthProfile` per definition by default. Profiles are copied independently. Null disables soil stress for legacy configurations.
- `FieldCellState`: integer `growth_elapsed_ticks` plus fractional `growth_remainder` in [0,1), `vitality` in [0,1], and accumulated `yield_quality_loss` in [0,1]. Reset values are 0, 0, 1, 0 respectively. Values on empty cells are neutral and unused.
- Profile defaults: N/K minimum 0.4, pH interval [6,8] with falloff 2, moisture interval [0.3,0.7] with falloff 0.3, vitality loss coefficient 0.05 and quality loss coefficient 0.025 per turn. All are configurable and validated.
- Phosphorus remains tracked but is not used by this increment's approved N/K formulas. Soil values are read each turn; this increment adds no nutrient consumption, watering or weather-update system.

## Pure growth evaluation

`src/simulation/models/crop_growth_model.gd` evaluates without mutating inputs:

1. Nutrient deficiency = clamp((minimum - value) / minimum, 0, 1); a zero minimum disables that deficiency term.
2. Interval stress = clamp(distance outside the inclusive optimal interval / falloff, 0, 1).
3. Overall stress is the maximum of N, K, pH and moisture stresses. Hydration suitability is one minus moisture stress.
4. Growth credit = (1 - stress) * pre-turn vitality. Add credit to the fractional remainder and convert whole units into integer ticks, capped at maturity. Discard leftover credit at maturity.
5. Vitality loses stress times its configured loss coefficient; accumulated quality loss gains stress times its coefficient. Both remain bounded. No automatic recovery is included.

Mature, uncollected crops continue accumulating neglect penalties. Zero vitality stalls further growth; it does not modify disease categories or compartment fractions.

## Transactions and harvesting

`FarmingController.advance_growth()` evaluates a copied grid and commits only after all results validate. The existing whole-turn transaction rolls back lifecycle state if later turn processing fails. Transfer preserves all crop lifecycle fields while keeping destination soil; planting, removal, and harvesting reset the crop payload.

`harvest_crop(coordinates) -> HarvestResult` rejects uninitialized, invalid, empty or immature targets. On success it returns a detached receipt containing crop ID, coordinates and `quality_multiplier = 1 - yield_quality_loss`, clears the crop atomically, and emits one cell change after commit. Harvest does not advance time. There is no inventory, currency, base yield amount or reward economy in this increment.

## Presentation and setup

The persistent `HUD/HarvestButton` sits above Zoom/Reset, toggles Harvest mode, and uses the same Android safe-area inset script. It is separate from the existing main panel so that panel's layout does not expand. Choosing a mature tile collects the crop and reports yield quality. Existing inspector text now includes moisture, vitality and quality; no runtime UI nodes are created.

The updated UI baker and `tools/setup_field_tools.gd` save through Godot editor APIs and preserve the scene UID. Reload `field_prototype.tscn` before playtesting. No crop artwork or animation resources were regenerated.

## Verification

`tests/simulation/crop_growth_test.gd` covers optimal/deficient conditions, pH extremes, drought/over-saturation, inclusive thresholds, fractional growth, accumulated penalties, maturity, profile/soil validation, pure evaluation, copy/transfer/reset, staged rollback, harvest rejection and duplicate prevention, and native saved-scene Harvest input.

At the original lifecycle checkpoint, the suite had twelve tests. Eleven passed; the crop-visual test had 35 failures. An isolated archive of committed HEAD `6ff33f3` reproduced exactly the same 35 failures, confirming they predate this lifecycle implementation. Those animation/static-art issues were subsequently fixed; that checkpoint passed all fifteen tests. The November 6 run is failing on scene grass-atlas errors and twelve animation-speed mismatches; section 15 of `PROJECT_HANDOFF.md` records the current status and the separately passing new grass-overlay test. Physical Android validation remains outstanding.


## Subsequent approved weather/tools increment

Watering, fertilizing and a turn-based hydration service were subsequently approved and implemented. See [WEATHER_AND_SOIL_TOOLS.md](WEATHER_AND_SOIL_TOOLS.md) for controls and turn ordering. That weather checkpoint passed twelve of thirteen tests. Subsequent editor-preview and crop-animation work brought the current suite to fifteen of fifteen passing. The earlier twelve-test result above records the lifecycle checkpoint.


The animation regression fix is documented in section 14 of `PROJECT_HANDOFF.md`: per-frame checks, all-frame shared sizing and stem-base anchoring now replace the failing static-strip assumptions. No lifecycle formulas were changed by that fix.
