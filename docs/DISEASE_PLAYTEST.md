# Interactive Rice Blast playtest

The resources and controls are already saved and wired in field_prototype.tscn.
Reload that scene if it was open while the setup ran, then press F5.

1. Select Rice and plant several adjacent paddy-mud tiles.
2. Click the selected Rice button again to return to Inspect mode.
3. Inspect one of those rice tiles and click **Seed Infection**.
4. Press **Next Turn** and inspect neighboring crops to observe compartment changes.

Disease Default uses Spatial SIR. For Spatial SEIR or Stochastic CA-SIR, select
the algorithm before seeding. Continuous patient zero starts at S=0.8, I=0.2;
CA starts at I=1. Selecting CA after fractional spread is rejected and the HUD
selection rolls back with an explanation. Restart play to obtain a clean board.
CA spread is stochastic; no single next-turn infection is guaranteed.

Seed Infection is enabled for a clean, compatible inspected crop. Logic also
rejects repeated seeding, invalid coordinates, empty tiles and incompatible hosts.
Seeding preserves growth/soil and does not advance the clock. The disease name
and fractions refresh immediately in the inspector. Existing crop markers still
indicate growth/maturity, not infection intensity.

## Saved resources and authoring

- src/data/resources/diseases/rice_blast.tres
- src/data/databases/default_disease_database.tres

Defaults: beta 0.6, sigma 0.5, gamma 0.15, xi 0, mortality 0.10; Moore radius 1,
distance decay 0.3. Temperature response is enabled for 20–30°C; humidity
sensitivity is 0.5. Nutrient effects remain disabled. These are illustrative,
uncalibrated playtest parameters.

TurnController and TileInspectorView reference the same external catalog.
The presenter selects Rice Blast for the seed action. Both new controls are
owned by the scene root and editable in the Editor. Algorithm selection goes
through TurnController validation; patient-zero changes go through FarmingController.

## Repeatable setup

Open tools/setup_disease_playtest.gd in the Script Editor and run it with
Ctrl+Shift+X. It creates missing resources, validates existing resources without
overwriting them, invokes the UI baker, assigns references, and saves through
Godot APIs. It preserves the scene UID and disables thumbnail generation for
headless compatibility. Existing invalid resources cause an error rather than
being replaced. The baker's node construction and ownership remain undoable;
the setup's saved resource files are not an undoable editor operation.

Automation uses a normal headless editor with GODOT_PLAYTEST_SETUP=1 via the
environment-gated harness. Do not combine it with GODOT_EDITOR_TEST. The strict
runner removes the setup flag from its subprocess environments.

Verified: setup passes without diagnostics, a rerun leaves both resource files
byte-for-byte unchanged, the main scene UID is preserved, and all seven strict
tests pass with no warnings/errors or resource leaks. The new disease playtest
test reloads the saved scene in a fresh process and checks native seed-button
input, external references, ownership, each algorithm, rejection/rollback, and spread.
