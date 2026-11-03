# Step 2.3: Tile inspector

**Updated workflow:** See [Persistent UI setup](BAKE_UI_SETUP.md). The complete baker now handles HUD and inspector ownership. Runtime auto-layout has been removed; the responsive-layout notes below describe the earlier prototype.

## Automated Editor builder (recommended)

1. Stop the playtest and open field_prototype.tscn as the active scene.
2. Open res://src/presentation/ui/inspectors/build_tile_inspector_scene.gd
   in Godot's Script Editor. Do not attach this EditorScript to a scene node.
3. Choose the Script Editor's File > Run command, or press Ctrl+Shift+X.
4. The builder creates HUD/TileInspectorPanel, its complete hierarchy, all
   exported child bindings, and the presenter's tile_inspector reference.
5. Optionally assign an authored DiseaseDatabase to the panel's
   disease_database property. The builder preserves an existing assignment.
6. Save the active scene normally with Ctrl+S, then play with F6.

The builder uses Godot's node and property APIs and sets scene ownership so
children and exported references survive saving. It does not write scene text,
edit UIDs, auto-save, or create duplicate signal connections.
Runtime signals are connected by the inspector and presenter.

Rerunning reuses compatible nodes and fills missing expected nodes/bindings.
It preserves existing node styling and catalog assignments. A conflicting
node type, unrelated panel script, nested scene ownership, or presenter
reference to another inspector stops the build instead of replacing content.
Build changes are one Undo/Redo action in the active scene's history.

Type clarification: display_cell takes FieldCellState, not FieldGridState.
The latter describes an entire grid and does not identify which cell to show.
The presenter extracts the selected cell from a fresh FieldGridState snapshot.

## Scripts

- res://src/presentation/ui/inspectors/tile_inspector_view.gd
  - class_name TileInspectorView; extends PanelContainer.
  - display_cell(cell_state: FieldCellState, crop_data: CropData) -> void
  - clear_display() -> void
  - validate_configuration() -> PackedStringArray
  - signal close_requested
- res://src/presentation/world/field_prototype_presenter.gd
  - Adds the required exported tile_inspector reference.
  - Starts in Inspect mode; crop buttons toggle planting mode.
  - Refreshes the inspected tile from a new snapshot after turns and changes.

No Data or Simulation schemas change. No crop-health metric is introduced.
The inspector reads values immediately; it does not retain or mutate snapshots.

## Build this tree in the Editor

Add TileInspectorPanel directly under HUD (CanvasLayer), as a sibling of the
existing HUD/Panel. Do not place it inside the existing HUD controls container.
Attach tile_inspector_view.gd only to TileInspectorPanel.

```text
HUD (CanvasLayer)
  Panel (existing PanelContainer; keep existing children)
  TileInspectorPanel (PanelContainer) [tile_inspector_view.gd]
	Margin (MarginContainer)
	  Layout (VBoxContainer)
		Header (HBoxContainer)
		  TitleLabel (Label)
		  CloseButton (Button)
		Scroll (ScrollContainer)
		  Content (VBoxContainer)
			TerrainHeading (Label)
			TerrainLabel (Label)
			SoilPHLabel (Label)
			MacronutrientsLabel (Label)
			TerrainSeparator (HSeparator)
			CropHeading (Label)
			CropNameLabel (Label)
			GrowthLabel (Label)
			GrowthBar (ProgressBar)
			DiseaseSeparator (HSeparator)
			EpidemicHeading (Label)
			DiseaseLabel (Label)
			StateLabel (Label)
			RemovedOutcomeLabel (Label)
			FractionsHeading (Label)
			Compartments (GridContainer)
			  SusceptibleLabel (Label)
			  SusceptibleBar (ProgressBar)
			  ExposedLabel (Label)
			  ExposedBar (ProgressBar)
			  InfectedLabel (Label)
			  InfectedBar (ProgressBar)
			  ImmuneLabel (Label)
			  ImmuneBar (ProgressBar)
			  DeadLabel (Label)
			  DeadBar (ProgressBar)
```

Header is outside Scroll so Close remains accessible when the body scrolls.
All nodes except TileInspectorPanel have no scripts.

## Editor layout

1. Set TileInspectorPanel Visible off for the initial Editor view.
   The script also hides it during startup.
2. Set Margin theme overrides to 12 pixels on all four sides.
3. Set Content horizontal Container Sizing to Expand + Fill.
4. Set Scroll vertical Container Sizing to Expand + Fill, with no custom
   minimum height. Do not enable Follow Focus unless desired.
5. Set Compartments Columns to 2. Add the label/bar pairs in the exact order above.
6. Set TitleLabel horizontal Container Sizing to Expand + Fill.
7. Set heading text:
   - TerrainHeading: Terrain & soil
   - CropHeading: Crop
   - EpidemicHeading: Epidemic state
   - FractionsHeading: Compartment fractions
8. Leave other label text blank; the script fills it.
9. Leave Auto Layout enabled. Default inspector dimensions are 340 x 560
   viewport units, aligned right with a 12-unit margin. Height and width
   shrink to the available logical viewport; the body scrolls.
10. Leave bars' Custom Minimum Size at zero in the Editor. The script
    applies 96 x 16, sets the range to 0–100, and hides built-in percentage
    text because each paired Label includes its percentage.

The panel consumes pointer input, including blank interior space.
Decorative children ignore pointer input; Close and Scroll remain interactive.
The presenter keeps the original HUD's decorations pass-through without
overwriting inspector input behavior. Do not manually connect signals.

## Inspector bindings

On TileInspectorPanel, drag these nodes into their exported properties:

| Export | Node |
| --- | --- |
| close_button | Header/CloseButton |
| scroll_container | Scroll |
| title_label | Header/TitleLabel |
| terrain_label | Content/TerrainLabel |
| soil_ph_label | Content/SoilPHLabel |
| macronutrients_label | Content/MacronutrientsLabel |
| crop_name_label | Content/CropNameLabel |
| growth_label | Content/GrowthLabel |
| growth_bar | Content/GrowthBar |
| disease_label | Content/DiseaseLabel |
| state_label | Content/StateLabel |
| removed_outcome_label | Content/RemovedOutcomeLabel |
| susceptible_label / susceptible_bar | Compartments/SusceptibleLabel / SusceptibleBar |
| exposed_label / exposed_bar | Compartments/ExposedLabel / ExposedBar |
| infected_label / infected_bar | Compartments/InfectedLabel / InfectedBar |
| immune_label / immune_bar | Compartments/ImmuneLabel / ImmuneBar |
| dead_label / dead_bar | Compartments/DeadLabel / DeadBar |

The paths above abbreviate the tree for readability; use Inspector node
assignment rather than typing paths into scripts.

Assign disease_database if you have an authored DiseaseDatabase Resource.
An empty or unassigned catalog is allowed: an active unresolved disease
displays Unknown disease (ID ...). A tile with no active disease displays None.

On FieldPrototype, assign its new tile_inspector export to HUD/TileInspectorPanel.
All existing presenter, view, controller, and HUD references remain required.
Until the new panel and its bindings are assigned, startup deliberately reports
the missing references and disables interaction.

## User interaction

- Start: Inspect mode, with all crop buttons unselected.
- Click any field tile: open the inspector; nothing is planted.
- Click a crop button: enter Plant mode, highlight that button, close the inspector.
- Click another crop button: switch the selected crop.
- Click the selected crop button again: return to Inspect mode.
- In Plant mode, tile clicks use the existing planting rules.
- Next Turn works in either mode and refreshes an open inspector.
- Close clears the inspection selection; subsequent turns do not reopen it.

Empty cells show No crop and Not applicable for growth/epidemic values.
Grass without soil shows No soil data. Nutrients display normalized availability,
not health or agronomic concentration. Unknown crop definitions are explicit.
Invalid fractions show INVALID and hide the corresponding bar; no input values
are clamped or altered. A compartment sum different from 1.0 is flagged.
Categorical state and fractions remain separate; the view never infers state
from the fraction values.

## Verification

Both production scripts passed Godot parser checks. The extended
tests/logic/field_scene_integration.gd passed using an in-memory inspector
fixture when the saved scene has no panel yet; it does not save scene changes.
Checks cover Inspect/Plant mode switching, no planting during inspection,
open/close behavior, turn refresh, click blocking, missing disease fallback,
invalid fractions, snapshot immutability, and small-viewport sizing.

The CLI environment still reports log-writing errors, and the scene copy
available during testing still reported the previously identified stale atlas
definitions. These are separate from the passing inspector behavior checks.
After building your real node tree, verify layout and scrolling in the Editor.

The automated builder additionally passed a headless editor test covering
creation, all exported bindings, scene ownership, Undo/Redo, rerunning without
duplicate nodes, and an in-memory PackedScene round trip. The test did not
save the user's scene.
