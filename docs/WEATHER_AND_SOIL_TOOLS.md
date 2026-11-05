# Inspector weather and soil tools

Implemented after explicit PCI approval on 2026-11-05 (Asia/Shanghai). These are normalized crop-hydration gameplay parameters, not calibrated climate or agronomic measurements.

## Use in the Editor

Reload `field_prototype.tscn` after setup. Select the root-level `WeatherManager` or `SoilToolController` node in the scene tree to tune exported properties. During play, edit the Remote tree for immediate runtime changes; edit the Local scene and save for persistent defaults.

`WeatherManager` is referenced by `TurnController.weather_manager`. `SoilToolController.farming_controller` and the presenter's `soil_tool_controller` reference are saved. No autoload or frame timer is needed. `tools/setup_field_tools.gd` creates missing services and runs the UI baker through Godot APIs, preserving existing service configuration and the scene UID.

## Weather properties and units

- `enabled`: bypass weather updates when false.
- `debug_moisture_updates`: enabled by default; prints changed tile count and before/after mean moisture after a successful full turn. Balanced settings explicitly report no net change. Failed turns do not publish a committed summary.
- `base_temperature_celsius`: default 25; used for evaporation only.
- `rainfall_per_turn`, `evaporation_per_turn`: normalized moisture units, both default 0.02. Baseline defaults deliberately balance, preserving existing initial crop growth.
- `ambient_humidity`: normalized [0,1], default 0.5.
- `rainfall_moisture_scale`: default 1.
- `temperature_reference_celsius`, `temperature_evaporation_sensitivity`: defaults 25 and 0.02 per degree.
- `humidity_reference`, `humidity_evaporation_sensitivity`: defaults 0.5 and 1.
- `minimum_evaporation_factor`, `maximum_evaporation_factor`: defaults 0 and 3, applied independently to temperature and humidity factors.
- `fluctuations_enabled`, `temperature_amplitude`, `rainfall_amplitude`, `cycle_length_turns`: optional deterministic sine fluctuations, disabled with zero amplitudes by default; cycle length defaults to 8.
- `source_mode`, `climate_resource`, `climate_csv_path`: future data-source hooks. Only Inspector mode is implemented. Selecting Resource or CSV while enabled rejects the turn with an explicit diagnostic; no files are silently loaded or ignored.

For a visible drying demo, lower rainfall below evaporation. For a repeating cycle, enable fluctuations and set nonzero amplitudes. A change made at runtime applies on the next successful turn.

## Hydration calculation

For zero-based turn index t and positive cycle length L, wave = sin(2*pi*(t mod L)/L), or zero when fluctuations are disabled.

- temperature = base temperature + wave * temperature amplitude
- rain = clamp(rainfall baseline + wave * rainfall amplitude, 0, 1)
- temperature factor = clamp(1 + (temperature - reference temperature) * temperature sensitivity, configured factor bounds)
- humidity factor = clamp(1 + (reference humidity - ambient humidity) * humidity sensitivity, configured factor bounds)
- evaporation = evaporation baseline * temperature factor * humidity factor
- next moisture = clamp(current moisture + rain * rainfall scale - evaporation, 0, 1)

The pure arithmetic lives in `src/simulation/models/soil_moisture_model.gd`; `src/logic/environment/weather_manager.gd` validates and applies it to staged soil cells. Empty soil tiles also update; grass with null soil is skipped. Ambient weather settings here do not overwrite `AbioticState` temperature/humidity.

Turn order is validate, stage weather/moisture, stage crop growth, existing simulation processing, commit clock, and emit `turn_completed`. A later failure restores moisture and all lifecycle state. Weather uses the existing clock as its only phase input, so failed turns cannot consume weather progression. Weather emits no intermediate per-cell change events.

## Water and Fertilize

`SoilToolController` exports `water_infusion_amount`, `nitrogen_boost_amount` and `potassium_boost_amount`, each defaulting to 0.1. These are fractions: 0.1 adds ten percentage points, not ten percent of the current value.

Choose the persistent Water or Fertilize button, then click/tap a soil tile. Both empty and occupied plantable soil can be managed. Water adds moisture; Fertilize adds N and K independently. Each value saturates at one. Other soil metrics and crop payload fields are preserved. Invalid targets/configuration fail without mutation. A saturated or zero-amount action is a successful no-op with no change signal. A changed tile commits once and emits one `cell_changed`; tools never advance turns.

Buttons are baked independently of the main HUD panel and inherit its input guards, tool exclusivity and gesture suppression. The standalone controls use the shared Android safe-area inset script. Physical Android testing remains outstanding.

No nutrient consumption, irrigation animation, terrain tilling, inventory costs, or external CSV parser is included. Existing disease-model formulas and configuration were not changed.

## Verification

`tests/logic/weather_soil_tools_test.gd` verifies configured rainfall/evaporation, warm/dry evaporation factors and caps, normalized bounds, all soil tiles, disabled weather, live configuration changes, unsupported sources, deterministic cycles, weather-before-growth ordering, full failed-turn rollback, local tool additions/no-ops/rejections, signals, saved wiring and native HUD/Next Turn input.

Latest full strict result: 12/13 tests pass, with no engine warnings/errors in the run. The crop-visual test retains the same 35 assertion failures independently reproduced against committed HEAD `6ff33f3` during the preceding lifecycle work. No new regression was found. The full suite is not green.


## Static-moisture troubleshooting

The saved Next Turn route already invokes weather before crop growth. With default rainfall and evaporation both 0.02, temperature 25 and humidity 0.5, the net moisture change is exactly zero. This is not a skipped tick. Enable `debug_moisture_updates` to see `Weather turn N: ...` after each successful turn. To demonstrate drying, use rainfall 0 and evaporation 0.05; to demonstrate wetting, use rainfall 0.1 and evaporation 0. Values already clamped at zero/one can also remain unchanged.

A fresh saved-scene integration test exercises balanced, wetting and drying settings through actual Next Turn button events and verifies that rolled-back turns do not publish successful-update diagnostics. Edit the Remote WeatherManager while running, or save Local values and restart play.
