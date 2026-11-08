# Automatic disease activation

Implemented November 8, 2026 (Asia/Manila). This feature schedules illustrative game encounters. Its probabilities and timing are game-design choices, not calibrated agricultural predictions.

## What the player experiences

Start a game, prepare plots, and plant sugarcane, rice, or corn on compatible terrain. End Turn updates weather, growth, and existing disease progression, then may introduce the session's disease into one eligible crop. A new introduction progresses for the first time on the following turn. Introductions are not guaranteed during a session.

The saved scene permits all nine catalog entries and uses the existing simulation models. The eight new drafts share a temporary fictional game preset; Rice Blast retains its existing settings. No symptom artwork, treatment actions, weather-based activation, or educational panels were added. Inspect disease state using the existing tile inspector; successful introductions also produce a short Output diagnostic.

Catalog update (November 8): all nine IDs are registered and allowed for automatic selection. The eight new entries remain labeled drafts despite being playable. RSSI is an insect pest temporarily represented by the same abstract rules, with pest-specific modeling still pending. See [catalog status](../src/data/resources/diseases/README.md) and [finalization notes](DISEASE_FINALIZATION.md). Only one compatible identity is selected per session.

## Inspector settings

Select `DiseaseActivationController` in `field_prototype.tscn`, then expand **Policy**, or open `src/data/resources/disease_activation/default_activation_policy.tres`.

| Setting | Initial value | Meaning |
|---|---|---|
| Enabled | true | Enables automatic introductions |
| Allowed Disease IDs | All nine IDs | Must refer to registered disease resources |
| First Eligible Turn | 3 | Earliest turn being completed that may introduce disease |
| Chance Per Eligible Turn | 0.25 | One game roll across the field, not a roll per crop |
| Cooldown Turns | 3 | Skip the next three completed turns after a successful introduction |
| Max Introductions Per Session | 2 | Counts successful introductions, not spread; zero disables introductions |
| Random Seed | 2026 | Reproducible activation sequence; changes take effect on reset |
| Design Note | Illustrative game settings | Records the settings' purpose |

Values inherited from the resource script appear in the Inspector even when omitted from the serialized resource. Edit and save resources through Godot. For a deterministic software playtest, set chance to 1 and first eligible turn to 1 on a test copy of the policy; automated tests do this without changing the saved policy.

## Rules

- At the first eligible opportunity, select one disease from the allowed catalog entries with eligible crops. Keep that disease for the session, including after its infected crops are removed. Selection and any chance roll commit only with a successful turn.
- Eligible crops must be compatible, fully susceptible, valid, and have no disease identity. Existing retained identities (including recovered crops) constrain selection. Multiple identities or a conflict with the selected identity skip introductions. Manual debug seeding is still available during play and is not counted as an automatic introduction.
- The simulation's active disease filter is respected. Allowed-but-unregistered IDs are configuration errors, not silently ignored.
- No eligible crop means no activation random draw and no introduction count. An existing cooldown still counts down on completed enabled turns. Disabling activation freezes its history until re-enabled or reset.
- Zero chance never introduces; chance one always introduces when otherwise eligible. Neither guarantees subsequent stochastic spread.
- Activation has its own RNG. Simulation RNG consumption cannot change its selection sequence. Whole-board outcomes also depend on simulation randomness and player actions.
- Pending farmer tasks block turns. Menu, victory, and game-over states block direct `TurnController.advance_turn()` calls as well as normal player advancement. Optional session binding permits standalone Logic tests.
- The terminal turn still runs existing weather/growth/simulation, but skips new introductions. The game-state manager checks the turn limit after commit.
- Play Again initializes the field and resets turn/activation history before returning to play. Repeated clock resets are safe and do not select a disease.

## Files and connections

| File | Responsibility |
|---|---|
| `src/data/resources/disease_data.gd` and `diseases/*.tres` | Existing disease definitions and simulation configuration |
| `src/data/databases/default_disease_database.tres` | Existing registered disease list |
| `src/data/resources/disease_activation_policy.gd` | Typed, validated scheduling settings |
| `src/data/resources/disease_activation/default_activation_policy.tres` | Saved scene policy |
| `src/data/state/disease_activation_state.gd` | Copyable session counters, selection, RNG state |
| `src/data/state/disease_activation_request.gd` | Proposed disease ID and tile |
| `src/logic/environment/disease_activation_controller.gd` | Produces a detached proposal; owns committed activation history |
| `src/logic/farming/farming_controller.gd` | Stages growth, simulation, and introduction; commits authoritative field |
| `src/logic/turns/turn_controller.gd` | Gates advancement, commits clock, checks session end, publishes activation diagnostic |
| `src/presentation/world/field_prototype_presenter.gd` | Binds session manager and handles Start/Play Again |

`Disease .tres files -> disease database -> activation controller <- policy + history + field snapshot -> proposed request -> FarmingController -> validated commit -> TurnController clock and notifications`.

Yes: each additional enabled disease needs its own `DiseaseData` resource in the existing database. It does not need its own activation script. RSSI means Red-Striped Soft Scale Insect; its enum ID remains unchanged, but representing this pest with the current disease models requires a separate review. It is now allowed as a temporary game abstraction; this does not implement a pest-specific model.

## Transaction and setup

FarmingController operates on a candidate grid through weather, growth, simulation, activation, and final validation. Failed processing leaves the authoritative grid and activation history untouched and restores simulation RNG/cap diagnostics. No per-cell notification or activation/weather success diagnostic is published for a failed turn. Successful automatic activation uses the existing debug seed representation without changing disease rates or formulas; its state update is staged, not immediately committed.

`tools/setup_disease_activation.gd` adds the activation node, saved policy, and shared GameStateManager wiring using Editor APIs. It preserves the main-scene UID and authored world data. Setup has already run; it is not a normal startup requirement. For rebuilding wiring only, use the normal editor lifecycle with `GODOT_ACTIVATION_SETUP=1`. The strict runner clears all setup flags.

## Tests

`tests/logic/disease_activation_test.gd` checks all three algorithms, eligibility, chance boundaries, cooldowns/limits, identities/filter, pending tasks, late failure rollback, independent RNGs, committed notifications, final-turn suppression, menu/victory/game-over gating, and the saved scene's Start/Play Again flow.

`tests/logic/gameplay_test_fixture.gd` supplies explicit terrain and starts existing scene-based tests. It disables activation on a copied policy so unrelated tests are deterministic; it never saves or changes shared resources.

Run the full suite with `tools/run_tests.py --godot <Godot executable>`. Add `--test tests/logic/disease_activation_test.gd` for the activation test alone. Timeout failures are reported and the runner continues to remaining tests.

Verification on November 8: activation passes without warnings/errors. The full 19-test run initially passed 14 tests; after correcting the crop-growth scene fixture, a six-test targeted rerun passed all selected tests. Combined current results are 15 passing and four remaining failures: crop animation speed, camera/scenery assumptions, automatic-background preview expectations, and scenery TileSet independence. No full-suite green claim is made.

Playable-catalog follow-up: five targeted tests passed for catalog loading, all nine entries under all three algorithms, activation, existing disease playtest, and epidemiology models. The runner now registers 21 tests; the earlier full-run results above remain historical.
