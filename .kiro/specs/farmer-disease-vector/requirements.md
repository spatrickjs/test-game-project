# Requirements — Farmer as Disease Vector

Source [farmer_disease_vector.feature](../../../features/farmer_disease_vector.feature). All probabilities and durations are fictional gameplay settings.

## Glossary

- **Committed arrival** is the final stop where the queued field action successfully applies its effects.
- **Contamination** is session state indicating that the farmer carries a crop disease.
- **Eligible plot** is a healthy, susceptible crop compatible with the carried disease and free of applicable protection.

## Requirements

| ID | Requirement | Gherkin scenario |
|---|---|---|
| R1 | A new game starts with a clean farmer. A committed action on an infected plot contaminates the farmer. | Farmer becomes contaminated after acting on an infected plot |
| R2 | A contaminated farmer's committed action on an eligible plot makes one transmission check using the configured chance and the disease-activation random stream. A successful roll infects the plot. | Contaminated farmer can infect a healthy plot |
| R3 | A clean farmer's action leaves a healthy plot healthy with respect to farmer transmission. | Clean farmer never infects a plot |
| R4 | With the same seed, initial state, and ordered actions, both games produce identical infection outcomes. | Transmission is deterministic for a given seed |
| R5 | A transmission check leaves the simulation and decoration random streams unchanged. | Simulation and decoration random streams are unaffected |
| R6 | Movement makes no transmission check and does not advance the simulation clock. An eligible committed arrival makes its check exactly once. | No transmission occurs during movement; Transmission is committed on arrival only |
| R7 | A rejected action preserves contamination, plot state, and random streams and exposes a reason through `last_error`. | Rejected action does not change contamination or plot state |
| R8 | Failed staged validation preserves the authoritative grid, contamination, random streams, counters, and clock and sends no committed-state notification. | Failed commit preserves authoritative state |
| R9 | A successful transmission publishes a committed-state notification after commit. A snapshot read from the callback shows the infection. | Observers are notified after a committed transmission |
| R10 | Grid snapshots are detached. Mutating one cannot change live plots or the farmer's contamination. | Views receive detached snapshots only |
| R11 | Farmer transmission leaves an already infected plot's infection state unchanged. | Already infected plot is not re-infected |
| R12 | A fenced cell or a healthy plot with active protective treatment is ineligible for transmission. | Fenced or protected plot resists transmission |
| R13 | Contamination clears after the configured number of completed turns without contact with an infected plot. | Contamination clears after the configured duration |
| R14 | Presentation can read the current contamination flag without access to a mutable reference to the authoritative farmer state. | Contamination state is exposed to the presentation layer |

## Non-goals

- New HUD artwork, player cleaning actions, save-game restoration, or changes to turn-based disease spread and introduction rules.
- Agricultural prediction or real-world transmission calibration.
