# Step 4.2: crop removal and transfer

The saved prototype includes Shovel and Move buttons in the existing HUD row.

- **Shovel:** click a crop to destroy it. The tool remains active for repeated use.
- **Move:** click a crop, then an empty tile whose terrain permits that crop.
  An invalid destination leaves the source intact and selected for another try.
- Click the selected source again to cancel that move. Clicking the active tool
  again, selecting another crop/tool, or pressing Escape clears the selection.
  A completed turn also clears pending transfer selection.

These actions are instantaneous and do not advance turns or award harvest rewards.
The inspector is closed when entering either management mode. Return to Inspect
by toggling the active tool off or pressing Escape.

## State and layer boundaries

`FarmingController.remove_crop()` rejects empty/out-of-bounds targets and delegates
to the existing `clear_crop()` reset. Empty cells have no crop, zero growth, no
active disease, categorical S/NONE and **zero** S/E/I/immune/dead fractions. Soil
and terrain remain in place. This removes the host and its infection contribution;
it does not change neighborhood geometry or create a dispersal-blocking terrain.

`FarmingController.transfer_crop()` validates the destination using the existing
planting rules, stages the move on a copied grid, validates the complete candidate,
then commits once. It copies crop identity, exact growth ticks, disease identity,
categorical state/outcome and all five fractions. Coordinates, terrain and soil
belong to their original locations. Incompatible terrain, occupied targets,
same-cell moves, invalid state and missing/out-of-bounds sources are rejected
without changing state or emitting change signals. Both endpoints are committed
before their `cell_changed` signals are emitted.

No Simulation formulas or Data schemas changed. Presenter tool modes route input
to Logic; FieldWorldView uses detached snapshots, calls `erase_cell()` for empty
coordinates, and renders the existing growth-stage tile at the new destination.
The transfer is an immediate tile update rather than an animation or a growth tick.

## Persistent authoring and verification

`tools/bake_ui_to_scene.gd` now creates and wires both buttons using its existing
Undo/Redo and scene ownership workflow. `tools/setup_field_tools.gd` runs the baker
and saves the prototype through Godot APIs while checking the main-scene UID.
Run that EditorScript with Ctrl+Shift+X, or use the normal editor harness with
`GODOT_FIELD_TOOLS_SETUP=1`. The strict test runner removes that setup flag.

The strict suite now includes nine passing tests. The added
`tests/logic/field_management_test.gd` checks native HUD/field clicks, wrong-terrain
retry, transfer, erasure, unchanged turns, exact mixed-compartment payload copying,
location-specific soil, rejected moves, infected removal and source cancellation
on tool changes. Existing UI, simulation and growth-render tests also pass.

Rendered verification uses the same test with `-- --capture`; screenshots are
written to `.godot/field_tools_moved.png` and `.godot/field_tools_removed.png`.
The D3D12 Mobile run passed with no engine warnings/errors.
