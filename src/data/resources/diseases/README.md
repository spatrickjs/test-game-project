# Disease and pest catalog

All nine existing IDs now have saved resources and are registered in `../../databases/default_disease_database.tres`.

| Resource | Crop | Current status |
|---|---|---|
| `rice_blast.tres` | Rice | Existing illustrative playtest; enabled for automatic introductions |
| `rice_tungro.tres` | Rice | Playable draft; temporary shared preset |
| `bacterial_leaf_blight.tres` | Rice | Playable draft; temporary shared preset |
| `sugarcane_smut.tres` | Sugarcane | Playable draft; temporary shared preset |
| `leaf_scald.tres` | Sugarcane | Playable draft; temporary shared preset |
| `red_striped_soft_scale_insect.tres` | Sugarcane | Playable insect-pest draft; abstract model review pending |
| `common_corn_rust.tres` | Corn | Playable draft; temporary shared preset |
| `philippine_downy_mildew.tres` | Corn | Playable draft; temporary shared preset |
| `ear_rot.tres` | Corn | Playable draft; temporary shared preset |

Each resource uses the existing `DiseaseData` schema, with a unique ID, display name, and matching crop. Draft labels and Metadata record authoring status and category. The eight new drafts now use identical fictional progression settings (`temporary_shared_v1`), with no environmental profile or new trigger rules. Rice Blast retains its existing illustrative configuration.

Registration makes an entry available for catalog lookup. Automatic activation is controlled separately by `../disease_activation/default_activation_policy.tres`, which now permits all nine IDs at the user's request. Only one compatible identity is selected per session.

Draft status and gameplay availability are independent: these entries are active in the game but not scientifically validated. See [finalization notes](../../../../docs/DISEASE_FINALIZATION.md) for the review checklist and files to change later.

RSSI preserves the existing numeric enum ID for compatibility, but refers to Red-Striped Soft Scale Insect. It temporarily uses the same abstract compartment rules; no insect lifecycle or pest-specific behavior is implemented or validated.

Resources were created with Godot's serializer through `tools/setup_disease_catalog.gd`. The separate `tools/enable_draft_disease_playtest.gd` then configured the eight new drafts and expanded the activation policy. Both have already run; normal play does not require either. Do not rerun the playtest configuration tool after individual tuning, because it overwrites those drafts with its temporary preset. Rice Blast and the scene were verified unchanged during the playable update.

Verification: catalog, playable catalog (all nine entries under all three algorithms), activation, existing disease playtest, and epidemiology model tests passed without engine warnings/errors. The full suite was not rerun; earlier unrelated visual/world-layout failures remain recorded in the handoff.
