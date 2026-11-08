# Playable drafts: what still needs to be finalized

Updated November 8, 2026 (Asia/Manila).

## Current behavior

All nine registered entries are allowed by the saved activation policy. The game selects **one compatible identity per session**, not all nine at once. The eight new resources keep `(draft)` in their names and use one identical fictional game preset. Rice Blast retains its previous illustrative settings.

The new entries can now be introduced and can progress through the existing SIR, SEIR, and CA implementations. RSSI is also temporarily playable, using the same abstract rules; no insect lifecycle model has been implemented. Draft means the representation is unfinished, not that gameplay is disabled.

This update does not add disease symptom sprites, prevention/treatment actions, or disease-specific environmental triggers. Current crop growth/vitality/harvest-quality calculations are soil-based: activating a disease does not by itself implement disease-specific growth penalties, harvest losses, or visible damage. The inspector shows the model state.

## The simple finalization checklist

| Review item | What the team needs to decide | Where to change it |
|---|---|---|
| Correct identity | Confirm the name, crop, and pest/disease category with the expert | Individual `src/data/resources/diseases/*.tres` resources and their metadata |
| Educational objective | Write the main lesson and have the expert review the game's simplified representation | Content documentation first; future educational resources/UI |
| Model suitability | Decide what a tile and each model compartment mean in this educational game; determine whether the same abstract model is appropriate | `src/simulation/models/` only if the approved model contract must change |
| RSSI treatment | Decide whether to retain an explicitly simplified pest abstraction or design separate pest behavior | RSSI resource, simulation design, and related tests; keep enum compatibility |
| Game pacing | Playtest encounter frequency, first eligible turn, cooldown, session limits, and how the twenty-turn session feels | `src/data/resources/disease_activation/default_activation_policy.tres` |
| Progression settings | Keep documented game-design parameters for an educational abstraction, or obtain suitable quantitative evidence if making predictive claims | Each disease resource; record provenance and limitations |
| Gameplay consequences | Define what model state should mean for crop growth, harvest quality, removal, and recovery; avoid assuming the current labels already implement those effects | Approved changes to Simulation/Logic, including crop lifecycle and harvest contracts |
| Visible signs | Have experts review symptom illustrations and what players can infer from them; separate growth stage from symptom severity | Future Presentation assets and inspector/world rendering |
| Prevention and responses | Define simple expert-reviewed player choices and explain their limits; do not imply an instant cure | Future Logic actions, content, and UI |
| Evaluation | Test software correctness and gameplay separately from expert content review and player learning evaluation | `tests/`, thesis methods/results, and review records |
| Release status | Remove `(draft)` only after the agreed content, gameplay, and evaluation criteria are met | Resource names and authoring-status metadata; this does not itself enable/disable an entry |

Expert interviews can support educational content without supplying numerical outbreak forecasts. An educational release may retain openly documented game abstractions if that matches the approved thesis scope. Do not describe the game as scientifically predictive merely because the software tests pass. Ask the adviser to confirm the evaluation criteria for the thesis.

## Files to edit later

- **Individual disease resources:** identity and model configuration. Open through the Godot Inspector and save with Godot. Existing `beta`, `sigma`, `gamma`, `xi`, and outcome fields remain model parameters in simulation-time units; no mapping from turns to real days is established here.
- **Activation policy resource:** which entries may be selected and how often game encounters occur. Removing an ID disables automatic introductions of that entry without deleting its data.
- **Disease database:** registers resources. Registration alone does not configure gameplay availability or model suitability.
- **Simulation scripts:** change only when the model behavior needs to change. Simply adding different names does not implement distinct transmission mechanisms.
- **`tools/enable_draft_disease_playtest.gd`:** one-time authoring tool used for this update. **Do not rerun after individual tuning:** it overwrites the eight new resources with the common temporary preset and allows all nine IDs. Normal play never runs it.

The temporary preset is recorded in each new resource's Metadata as `temporary_shared_v1`, along with the draft status and this document's path. It supplies identical nonzero progression settings with no environmental modifier profile. These values were chosen for a software demonstration, not extracted from the interview. Do not interpret the differences between this preset and Rice Blast as biological comparisons.

## How to playtest a particular entry

For a focused software test, use a copy of the activation policy with only the desired ID permitted, start a fresh session, and plant the matching game crop. Inspect its state after introductions and later turns. Restore the normal policy afterward. The fixed seed reproduces the same activation sequence for the same eligible board; restarting alone does not guarantee a different selected disease.

Manual Seed Infection still uses the presenter's configured `playtest_disease_id` (Rice Blast by default). This update does not add a disease-selection menu. Mixing manually seeded identities can conflict with the existing single-disease scenario rules.

## Verification

`playable_disease_catalog_test.gd` exercises all nine saved entries under all three algorithms using the full catalog, repeats each fixture with the same seeds, checks automatic introduction, subsequent valid progression, continuous-model neighbor changes, CA categorical state, and absence of competing identities.

After this update, five targeted tests passed without engine warnings/errors: activation, catalog, playable catalog, existing disease playtest, and epidemiology models. The runner now registers 21 tests. The full suite was not rerun; earlier unrelated visual/world-layout failures remain in the handoff.
