# Repository findings — Hoe and Shovel

## DECISION-001 (resolved): Shovel keeps fence removal

Interpretation **A** was chosen. The Shovel (`TOOL_REMOVE`) removes crops
(`REMOVE_CROP`) and fences (`REMOVE_FENCE`), and **no longer digs grass**.
The Hoe (`TOOL_HOE`, new) takes over grass tilling (`DIG_GRASS`).

This keeps `features/fence_treatment.feature` valid (shovel destroys fences)
and is the smaller change. The two `separate-hoe-and-shovel.feature` copies
were reconciled to this interpretation.

## Verified source contracts

- `ToolMode` enum lives in `src/presentation/world/field_prototype_presenter.gd`
  (`INSPECT, PLANT, TOOL_REMOVE, TOOL_TRANSFER, TOOL_HARVEST, TOOL_WATER,
  TOOL_FERTILIZE, TOOL_WATER_BUCKET, TOOL_FENCE`). `TOOL_HOE` was **appended**
  (enum values are save-stable; never reorder). `FieldActionKind` in
  `src/data/enums/simulation_enums.gd` already had every kind this feature
  needs (`DIG_GRASS`, `REMOVE_CROP`, `REMOVE_FENCE`) — no new action kind.
- `_select_management_tool` already toggles to `INSPECT` on re-press, so the
  Hoe/Shovel toggle needs no new logic; only a `TOOL_HOE` label branch was added.
- `_refresh_tool_targets` derives eligibility from `_make_action` + `action_error`,
  so highlights and the drag context-lock (`_on_cells_selected` passes `kind`)
  follow automatically from the `_make_action` change — no separate predicate.
- `_make_action` `TOOL_REMOVE` previously branched `REMOVE_FENCE` / `REMOVE_CROP`
  / else `DIG_GRASS`. Under A the else branch became `REMOVE_CROP`; `TOOL_HOE`
  emits `DIG_GRASS`. Shovel therefore never produces `DIG_GRASS`.
- `farming_controller.action_error` `DIG_GRASS` branch had two messages
  (`"Remove the fence before digging."` for fences, `"Shovel conversion
  requires empty grass."` otherwise). Merged into one Hoe-facing message
  `"Hoe requires empty grass."`. No test pinned the old strings.
- Queue invariants (reservation `"This plot already has a queued action."`,
  turn-blocking, stale cancel) are unchanged and already tested.
- HUD buttons are built by `tools/bake_ui_to_scene.gd` (`@tool EditorScript`,
  Godot APIs, no raw scene text). The Hoe button was added there
  (`NODE_TYPES`, `HUD_BINDINGS`, `_preview_text`, toggle list). Materializing
  it in `field_prototype.tscn` requires running `tools/setup_field_tools.gd`
  in the Godot editor; `hoe_button` is null-safe until then.
- `docs/QUEUED_FIELD_ACTIONS.md` described the shovel as digging grass; updated.

## Notes / assumptions

- `hoe_button` is optional in `validate_configuration` (matches the other tool
  buttons) so the scene validates before the editor bake is run.
- Tests call `_on_hoe_pressed()` directly; this works whether or not the
  Hoe button node exists, because the handler only changes tool mode.
