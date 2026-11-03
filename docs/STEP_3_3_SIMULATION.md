# Step 3.3: switchable epidemic models

Implemented in SimulationController plus CompartmentMath, SpatialSIRModel,
SpatialSEIRModel, and StochasticCASIRModel under src/simulation/models/.
All are scene-independent RefCounted classes.

## Configuration

- algorithm_override = -1 uses DiseaseData.default_algorithm. Values 0, 1, 2
  select Spatial SIR, Spatial SEIR, stochastic CA-SIR.
- active_disease_filter = -1 considers registered diseases. Set it to a
  DiseaseId for a single-disease benchmark. Cells carrying other diseases are
  frozen by the filter and cannot contribute pressure to the selected disease.
- time_step defaults to 1.0; it must be finite and positive.
- rng is an injectable RandomNumberGenerator. Assign rng.seed for reproducible
  runs on the same Godot version. For comparison runs, start from identical
  grid copies and RNG states; changing a seed alone does not reset the field.

Assign TurnController.disease_database in the Inspector. The inspector's optional
disease_database is a separate display reference; assign the same catalog there
to resolve names. No scene node is required for SimulationController.

## Mathematical contract

Pressure is the unnormalized sum of exp(-distance_decay * Euclidean distance)
times a compatible neighbor's infected fraction (continuous) or one-hot infected
indicator (CA). Only hosts with the same active disease contribute. Grass/empty
cells remain geometry and do not block longer-range dispersal.

Every rate uses 1 - exp(-rate * time_step). Continuous paired flows are evaluated
from old compartments only: S to I or E, E to I in SEIR, I to immune/dead, and
immune to S. Removal is split by mortality_probability. CA draws at most one
compartment transition per cell per tick, with a separate mortality decision
when removal occurs. Probability endpoints are handled exactly. Death is absorbing.

Continuous fractions remain authoritative; categorical fields are not thresholded
to invent a dominant state. CA synchronizes categories and one-hot fractions.
Recovered disease identity is retained through waning so the same disease can
reinfect the cell later. Clearing/replanting removes that identity.

## Validation, staging and switching

validate_turn() reports errors without mutation. process_turn() returns bool and
sets last_error. Empty catalogs safely perform no epidemic work. Nonempty
catalogs require every active disease to be registered and host-compatible.
Non-susceptible compartments need an active disease identity.

SIR/CA reject any E > 0. CA additionally requires exact one-hot fractions; there
is no implicit probabilistic projection of mixed stands. One-hot continuous
state is converted to consistent categorical state on CA evaluation.

Cells and definitions are traversed in canonical coordinate/ID order.
Evaluation reads a detached snapshot and stages results. No authoritative
compartment changes occur until all results validate; a failed evaluation
restores RNG state. Multiple positive disease exposures of an unassigned host
are rejected instead of choosing a catalog-order winner.

FarmingController.advance_simulated_turn() validates before growth and rolls
growth back if epidemic evaluation fails. TurnController increments/emits only
after success. Presentation continues to consume detached snapshots.

## Scope and verification

Optional temperature, humidity, nitrogen and potassium responses are now
implemented; see ENVIRONMENTAL_MODIFIERS.md. Generic nutrient/abiotic arrays and
base immunity are not additionally applied. These are bounded discrete-time models,
not empirically calibrated disease parameters or a continuous ODE solver.
Snapshot copies and neighborhood arrays prioritize correctness; mobile performance
must be measured before drawing benchmark conclusions.

The strict runner includes tests for SIR/SEIR fluxes and latent delay, no same-turn
chains, reflected-field symmetry, conservation under high rates, seeded CA,
catalog-order independence, death/waning endpoints, default/override switching,
incompatible switches, ambiguity/filter behavior, spatial decay, non-host
geometry, invalid input, atomic staging and RNG rollback. Existing UI, growth,
ownership and editor-shutdown tests remain enabled.
