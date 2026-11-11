# Design: Infected Debris Chance After Harvest

Implemented according to the resolved decisions in [requirements.md](requirements.md). Verification status is recorded in [tasks.md](tasks.md).

## Components

- Data: `InfectedDebrisPolicy` exposes chance 0.25 and seed 2026, rejecting non-finite or out-of-range probabilities. `FieldCellState.has_infected_debris` is copied independently of crop disease state.
- Logic: `InfectedDebrisResolver` provides eligibility and pure threshold evaluation. `FarmingController` owns the dedicated random stream and atomic harvest commit.
- Presentation: the existing inspector disease label displays “Infected debris”; occupied tiles retain their crop disease description alongside the debris indication.

No scene, asset, enum, autoload, transmission model, or save-restoration changes are required. Each controller creates its own default policy Resource and exposes it for Inspector overrides.

## Eligibility and randomness

A crop must have active disease and either categorical state I or a positive infected fraction. Exposed-only, recovered-only, and dead-only crops are ineligible without current infection. Existing maturity checks remain in force.

Each eligible harvest takes one draw, including chance endpoints. Convert the RNG integer with `float(randi()) / 4294967296.0` to guarantee [0, 1), then compare `draw < chance`. Ineligible harvests consume no draw. The dedicated RNG does not depend on simulation, activation, or decoration streams. Successful field initialization resets it to the configured seed; failed initialization preserves the session.

## Transaction

1. Validate the policy, target, maturity, and current field.
2. Capture crop identity and quality from pre-harvest state.
3. Copy the grid and RNG state; compute eligibility before resetting the crop.
4. Evaluate the staged draw where eligible, preserving any existing debris.
5. Clear crop lifecycle and disease state while retaining debris, terrain, and soil.
6. Validate the candidate through `_validate_harvest_candidate`.
7. Commit the grid and RNG together only on success, then notify observers.

The existing queue validates arrivals and revisions before invoking harvesting. Its completion signal retains the existing scoring route. Direct harvesting does not introduce another score path. Rejection, duplicate arrival, and candidate failure cannot consume authoritative RNG state. The validation method permits a test subclass to inject a post-draw failure.

## Lifecycle

The boolean flag is tile residue, without disease identity. Turns, crop removal, and harvesting preserve existing debris. Planting, fencing, and terrain conversion clear it explicitly. Moving a crop preserves the original debris flags at both locations. Shared crop reset does not clear residue. New fields start clear. No new cleanup tool or planting restriction is introduced.

## Verification

`tests/logic/infected_debris_test.gd` covers threshold boundaries, invalid configuration, eligibility, queue timing, duplicate/stale actions, scoring, quality, detached copies, inspector text, lifecycle, deterministic replay, and post-draw rollback. It uses the existing gameplay and inspector fixtures and is registered in `tools/run_tests.py`.

Full-suite diagnostics and manual visual/Android verification limitations are reported in tasks.md. A pass marker alongside engine errors does not constitute a clean test pass.
