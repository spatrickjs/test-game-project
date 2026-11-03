# Environmental transmission modifiers

## Authoring and defaults

Assign an optional TransmissionModifierProfile to DiseaseData.transmission_modifier_profile
using the Godot Inspector. A missing profile has neutral weather/nutrient effects.
New profiles disable temperature response and set humidity/N/K strengths to zero.
There are no new scene nodes or assets to wire.

Global weather remains FieldGridState.abiotic_state. AbioticState now includes
temperature_celsius = 25.0, validated as finite and at least -273.15 Celsius and
copied with snapshots. This is an uncalibrated placeholder, not an optimal
temperature for every Philippine crop/disease. Relative humidity remains 0–1.
FieldCellState.soil already supplies recipient nitrogen and potassium availability.

| Profile property | Default | Meaning |
|---|---|---|
| temperature_enabled | false | Opt into the temperature response |
| optimal_temperature_min / max | 20 / 30 °C | Uncalibrated favorable interval |
| temperature_falloff_celsius | 10 | Distance outside interval to reach floor |
| minimum_weather_multiplier | 0.1 | Configurable 0–1; zero permits full suppression |
| maximum_weather_multiplier | 2 | Weather ceiling, at least 1 |
| humidity_reference | 0.5 | Neutral reference; valid [0,1) |
| humidity_sensitivity | 0 | Strength in [0,1] |
| nitrogen_excess_strength | 0 | Strength in [0,1]; example 0.25 gives at most 1.25× |
| potassium_protection_strength | 0 | Strength in [0,1]; example 0.15 gives at most 15% protection |
| potassium_falloff | 0.2 | Positive width in normalized potassium units |
| maximum_effective_beta | 1,000,000 | Positive finite inverse-time-unit cap |
| maximum_hazard | 1,000,000 | Separate positive finite recipient hazard cap |

Profile bounds and defaults are implementation/authoring choices, not fitted
agronomic estimates. DiseaseData.validate() includes profile validation;
DiseaseData.copy() deep-copies the profile.

Nutrient effects use CropData.nutrient_requirement_rules for N/K healthy
intervals. Missing rules are neutral. The interval is reused; its generic
weight is not multiplied again. Profile strength defines the new effect.
Disease susceptibility rules, generic abiotic triggers, and base_immunity are
not also applied, avoiding double-counting. Those broader mechanisms remain
separate future work.

FarmingController supplies its crop catalog to SimulationController before
validation and evaluation. Direct simulation callers must assign
simulation.crop_database when N/K strengths are nonzero. Weather-only or
profile-free simulations need no crop catalog. Supplied catalogs are validated.

## Response equations

For temperature T, favorable interval [Tmin,Tmax], falloff width ΔT, floor m:

    dT = max(Tmin - T, 0, T - Tmax)
    MT = 1 - (1 - m) * clamp(dT / ΔT, 0, 1)

When temperature is disabled, MT = 1. For fractional humidity H:

    MH = 1 + humidity_sensitivity * clamp((H - H0) / (1 - H0), 0, 1)
    weather = clamp(MT * MH, minimum_weather_multiplier, maximum_weather_multiplier)

For receiving-cell nitrogen N and its crop's healthy upper bound Nmax:

    excess = clamp((N - Nmax) / (1 - Nmax), 0, 1)
    MN = 1 + nitrogen_excess_strength * excess

Nmax = 1 explicitly yields excess = 0, avoiding division by zero.
For potassium K, healthy interval [Kmin,Kmax], and falloff width ΔK:

    dK = max(Kmin - K, 0, K - Kmax)
    benefit = 1 - clamp(dK / ΔK, 0, 1)
    MK = 1 - potassium_protection_strength * benefit
    nutrient = MN * MK

The shared evaluator computes:

    effective_beta = min(beta_cap, disease.beta * weather * nutrient)
    hazard = min(hazard_cap, effective_beta * neighbor_pressure)
    infection_probability = 1 - exp(-hazard * time_step)

Zero factors remain zero, including zero pressure. Overflow-safe product
evaluation applies the beta cap after all protective factors are included.
Profile-free rates use the maximum finite float as a numerical overflow guard.

All three model evaluate() methods now receive the final hazard rather than
raw neighbor pressure. They do not multiply beta a second time. This is an
intentional internal API change. Continuous paired transfers, staging, and CA
RNG ordering are preserved. Disease-exposure ambiguity checks use the modified
hazard, so a fully weather-suppressed disease is not counted as active exposure.

## Diagnostics and invalid inputs

TransmissionModifiers.Result provides weather, nutrient, effective_beta, hazard,
and weather_capped/beta_capped/hazard_capped. SimulationController exposes
weather_cap_count, beta_cap_count, and hazard_cap_count for evaluated cell/disease
pairs in the last successful turn. They count computations, not infections;
failed turns discard the counts. Record these in future benchmark output to
make saturation visible. No output warnings are emitted for intentional caps.

Profile, weather, soil, and crop definition validation occurs before growth.
Invalid configuration is reported through the existing last_error path without
silent data repair. Bounded response functions and explicit caps are model
operations, not substitutes for input validation. Snapshot weather and receiving
cell soil are read without mutation; the input definition Resources are treated
as read-only throughout a turn.

## Evidence and thesis limitations

These response curves are approved phenomenological assumptions, not equations
fitted from the cited studies. Excess nitrogen and favorable temperature/moisture
are relevant to rice blast; leaf wetness requirements are not represented by
humidity alone. See [UC IPM rice blast guidance](https://ipm.ucanr.edu/agriculture/rice/rice-blast/).

Potassium protection is disease/context-dependent. A field study found that
potassium effects on panicle blast differed across nitrogen treatments:
[Prabhu et al. (1999)](https://apct.sede.embrapa.br/pab/en/article/view/5422).
Our product MN × MK omits explicit N–K interactions. Do not enable identical
responses for all nine diseases without supporting evidence/calibration.
Normalized soil values also need an empirical measurement-to-model mapping.

## Verification

Run tools/run_tests.py as described in TESTING.md. The strict suite now contains
six executable tests. New tests cover neutral defaults, interval endpoints,
temperature/humidity falloff, Nmax=1, smooth K response, missing nutrient rules,
deep copies, independent caps and overflow, zero pressure, invalid inputs,
recipient effects, SIR/SEIR fluxes, conservation, simultaneous updates, seeded
CA reproducibility, crop-catalog requirements, and complete weather suppression.
